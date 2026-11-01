#requires -Version 5.1
# dnet-artisan: Artisan-style helpers for the .NET CLI.
$script:DnetVersion = '0.2.0'
function Get-DnetProjects {
    param([string]$Directory)
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Directory)
    while ($pending.Count) {
        $folder = $pending.Pop()
        Get-ChildItem -LiteralPath $folder -File -Filter '*.csproj' -ErrorAction Stop
        foreach ($child in (Get-ChildItem -LiteralPath $folder -Directory -Force -ErrorAction Stop)) {
            if ($child.Name -notin @('bin','obj','.git','.vs','.idea','node_modules','packages') -and
                -not ($child.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                $pending.Push($child.FullName)
            }
        }
    }
}

function Get-DnetProjectInfo {
    param([string]$Path)
    [xml]$xml = [IO.File]::ReadAllText($Path)
    $rootNamespace = $xml.SelectSingleNode("/*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='RootNamespace']")
    $namespace = [IO.Path]::GetFileNameWithoutExtension($Path) -replace '[^A-Za-z0-9_.]', '_'
    if ($rootNamespace -and $rootNamespace.InnerText) { $namespace = $rootNamespace.InnerText }
    if ($namespace -match '^\d') { $namespace = '_' + $namespace }
    $testNode = $xml.SelectSingleNode("/*[local-name()='Project']/*[local-name()='PropertyGroup']/*[local-name()='IsTestProject']")
    [pscustomobject]@{
        Path = [IO.Path]::GetFullPath($Path)
        Directory = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($Path))
        Namespace = $namespace
        Web = [string]$xml.Project.Sdk -match 'Microsoft.NET.Sdk.Web'
        Test = ($testNode -and $testNode.InnerText -eq 'true') -or [IO.Path]::GetFileNameWithoutExtension($Path) -match '(Tests|Test)$'
    }
}

function Resolve-DnetProject {
    param([string]$ExplicitPath)
    if ($ExplicitPath) {
        $resolved = Get-Item -LiteralPath $ExplicitPath -ErrorAction Stop
        if (-not $resolved.PSIsContainer) {
            if ($resolved.Extension -ne '.csproj') { throw '--project must point to a .csproj file or project folder.' }
            return Get-DnetProjectInfo $resolved.FullName
        }
        $searchRoot = $resolved.FullName
    } else {
        $directory = (Get-Location).ProviderPath
        if (-not $directory) { throw 'Run dnet from a filesystem directory.' }
        while ($directory) {
            $direct = @(Get-ChildItem -LiteralPath $directory -File -Filter '*.csproj')
            if ($direct.Count -eq 1) { return Get-DnetProjectInfo $direct[0].FullName }
            if ($direct.Count -gt 1) { throw 'Several .csproj files found. Select one with --project PATH.' }
            $solutions = @(Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Extension -in @('.sln','.slnx') })
            if ($solutions.Count -or (Test-Path -LiteralPath (Join-Path $directory '.git'))) { $searchRoot = $directory; break }
            $directory = [IO.Path]::GetDirectoryName($directory)
        }
        if (-not $searchRoot) { throw 'No .NET project found. Change to your project folder or use --project PATH.' }
    }
    $projects = @(Get-DnetProjects $searchRoot | ForEach-Object { Get-DnetProjectInfo $_.FullName })
    $production = @($projects | Where-Object { -not $_.Test })
    $web = @($production | Where-Object { $_.Web })
    if ($web.Count -eq 1) { return $web[0] }
    if ($production.Count -eq 1) { return $production[0] }
    if ($projects.Count -eq 1) { return $projects[0] }
    throw 'Cannot select a unique .NET project. Use --project PATH.'
}

function Get-DnetSolution {
    param($Project)
    $directory = $Project.Directory
    while ($directory) {
        $solutions = @(Get-ChildItem -LiteralPath $directory -File | Where-Object { $_.Extension -in @('.sln','.slnx') })
        if ($solutions.Count -eq 1) { return $solutions[0].FullName }
        if ($solutions.Count -gt 1) { return $Project.Path }
        $parent = [IO.Path]::GetDirectoryName($directory)
        if (-not $parent -or (Test-Path -LiteralPath (Join-Path $directory '.git'))) { break }
        $directory = $parent
    }
    return $Project.Path
}

function Invoke-DnetDotnet {
    param([string]$Directory, [string[]]$Arguments)
    $executable = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
    if (-not $executable -and $env:ProgramFiles) {
        $standardDotnet = Join-Path $env:ProgramFiles 'dotnet/dotnet.exe'
        if (Test-Path -LiteralPath $standardDotnet) { $executable = $standardDotnet }
    }
    if (-not $executable) { throw '.NET SDK not found.' }
    $previousPath = $env:PATH
    $globalTools = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.dotnet/tools'
    Push-Location -LiteralPath $Directory
    if (Test-Path -LiteralPath $globalTools -PathType Container) {
        $env:PATH = $globalTools + [IO.Path]::PathSeparator + $previousPath
    }
    try {
        & $executable @Arguments
        $nativeExitCode = $LASTEXITCODE
        $global:LASTEXITCODE = $nativeExitCode
        if ($nativeExitCode -ne 0) { throw "dotnet exited with code $nativeExitCode." }
    } finally { Pop-Location; $env:PATH = $previousPath }
}

function Get-DnetFolder {
    param($Project, [string[]]$Candidates)
    foreach ($candidate in $Candidates) {
        if (Test-Path -LiteralPath (Join-Path $Project.Directory $candidate) -PathType Container) { return $candidate }
    }
    return $Candidates[0]
}

function Assert-DnetIdentifier {
    param([string]$Identifier)
    $keywords = @('abstract','as','base','bool','break','byte','case','catch','char','checked','class','const','continue','decimal','default','delegate','do','double','else','enum','event','explicit','extern','false','finally','fixed','float','for','foreach','goto','if','implicit','in','int','interface','internal','is','lock','long','namespace','new','null','object','operator','out','override','params','private','protected','public','readonly','ref','return','sbyte','sealed','short','sizeof','stackalloc','static','string','struct','switch','this','throw','true','try','typeof','uint','ulong','unchecked','unsafe','ushort','using','virtual','void','volatile','while')
    if ($Identifier -cnotmatch '^[A-Za-z_][A-Za-z0-9_]*$' -or $Identifier -cin $keywords) { throw "Invalid C# identifier: $Identifier" }
}

function New-DnetSourcePlan {
    param($Project, [string]$Folder, [string]$Name, [string]$Declaration, [string]$Members='', [string]$Usings='', [string]$Attributes='', [string]$NamespaceOverride)
    if ($Name -match '(^[/\\]|:|\x00)' -or $Name -match '\.\.' -or $Name -match '\.') { throw 'Use a class name or slash-separated name such as Admin/Report. File extensions and traversal are not allowed.' }
    $segments = @($Name -split '[/\\]')
    foreach ($segment in $segments) { Assert-DnetIdentifier $segment }
    $namespace = $Project.Namespace
    $relativeParts = @()
    if ($Folder) { $relativeParts += $Folder }
    if ($segments.Count -gt 1) { $relativeParts += $segments[0..($segments.Count-2)] }
    if ($relativeParts.Count) { $namespace += '.' + ($relativeParts -join '.') }
    if ($NamespaceOverride) { $namespace = $NamespaceOverride }
    foreach ($segment in ($namespace -split '\.')) { Assert-DnetIdentifier $segment }
    $relativePath = (@($relativeParts) + @($segments[-1] + '.cs')) -join [IO.Path]::DirectorySeparatorChar
    $path = [IO.Path]::GetFullPath((Join-Path $Project.Directory $relativePath))
    if (-not $path.StartsWith($Project.Directory.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Generated file must stay inside the project.' }
    $content = ''
    if ($Usings) { $content += $Usings.TrimEnd() + "`r`n`r`n" }
    $content += "namespace $namespace`r`n{`r`n"
    if ($Attributes) { $content += $Attributes.TrimEnd() + "`r`n" }
    $content += "    public $Declaration`r`n    {`r`n"
    if ($Members) { $content += $Members.TrimEnd() + "`r`n" }
    $content += "    }`r`n}`r`n"
    [pscustomobject]@{ Path=$path; Content=$content; Namespace=$namespace }
}

function Write-DnetSources {
    param($Project, [object[]]$Plans)
    # Preflight every output before creating anything, including paired service/interface files.
    foreach ($plan in $Plans) {
        if (Test-Path -LiteralPath $plan.Path) { throw "File already exists: $($plan.Path)" }
        $parent = [IO.Path]::GetDirectoryName($plan.Path)
        while ($parent -and $parent -ne $Project.Directory) {
            if (Test-Path -LiteralPath $parent) {
                if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Refusing to generate through a directory link: $parent" }
            }
            $parent = [IO.Path]::GetDirectoryName($parent)
        }
    }
    $created = @()
    try {
        foreach ($plan in $Plans) {
            [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($plan.Path))
            $stream = [IO.File]::Open($plan.Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            $created += $plan.Path
            try {
                $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($plan.Content)
                $stream.Write($bytes,0,$bytes.Length)
            } finally { $stream.Dispose() }
        }
    } catch {
        foreach ($createdPath in $created) { [IO.File]::Delete($createdPath) }
        throw
    }
    foreach ($plan in $Plans) { Write-Host ('Created: ' + $plan.Path) -ForegroundColor Green }
    $global:LASTEXITCODE = 0
}

function Invoke-Dnet {
    param([string[]]$Arguments)
    if ($Arguments.Count -and $Arguments[0] -in @('--version','version','-v')) {
        Write-Output "dnet-artisan $script:DnetVersion"
        $global:LASTEXITCODE = 0
        return
    }
    if (-not $Arguments.Count -or $Arguments[0] -in @('help','list','--help','-h')) {
        @'
dnet - Artisan-style .NET commands

  make:controller Name [--resource]   API controller; --resource adds CRUD stubs
  make:class Name                    Class (use Helpers/Clock for subfolders)
  make:model Name                     Entity/Models class; not added to DbContext
  make:dto Name                       DTO with Dto suffix
  make:service Name [--interface]     Service, optionally with a paired interface
  make:interface Name                 Interface
  make:enum Name                      Enum
  make:migration Name [EF options]    dotnet ef migrations add

  serve [run options]                 dotnet watch run (hot reload)
  run [options]                       dotnet run
  build | restore | clean | format    Standard .NET commands
  test [options]                      Unit test project when uniquely discoverable
  package:add Package [options]       dotnet add package
  migrate [EF options]                dotnet ef database update
  migrate:status [EF options]         dotnet ef migrations list
  migrate:rollback Target [options]   dotnet ef database update Target
  db:context [EF options]             dotnet ef dbcontext list

Options: --project PATH chooses a .csproj or folder. Generators also accept
--namespace Company.App.Folder. Names can contain subfolders, e.g. Admin/Report.
Existing files are never overwritten. Controllers are scaffolds, not working CRUD.
EF commands require dotnet-ef and EF Core Design. No tools are installed automatically.
'@ | Write-Output
        $global:LASTEXITCODE = 0
        return
    }
    $command = $Arguments[0].ToLowerInvariant()
    $remaining = New-Object 'System.Collections.Generic.List[string]'
    $projectPath = $null
    $passThrough = $false
    for ($index=1; $index -lt $Arguments.Count; $index++) {
        if ($Arguments[$index] -eq '--') { $passThrough = $true }
        if (-not $passThrough -and $Arguments[$index] -eq '--project') {
            if ($index+1 -ge $Arguments.Count) { throw '--project requires a path.' }
            $index++; $projectPath = $Arguments[$index]
        } else { $remaining.Add($Arguments[$index]) }
    }
    $known = @('make:controller','make:class','make:model','make:dto','make:service','make:interface','make:enum','make:migration','serve','run','build','restore','clean','format','test','package:add','migrate','migrate:status','migrate:rollback','db:context')
    if ($command -notin $known) { throw "Unknown command '$command'. Run dnet list." }
    $project = Resolve-DnetProject $projectPath
    if ($command -like 'make:*' -and $command -ne 'make:migration') {
        $name = $null; $resource = $false; $withInterface = $false; $namespace = $null
        for ($index=0; $index -lt $remaining.Count; $index++) {
            switch ($remaining[$index]) {
                '--resource' { if ($command -ne 'make:controller') { throw '--resource is only supported by make:controller.' }; $resource=$true }
                '--api' { if ($command -ne 'make:controller') { throw '--api is only supported by make:controller.' } }
                '--interface' { if ($command -ne 'make:service') { throw '--interface is only supported by make:service.' }; $withInterface=$true }
                '--namespace' { $index++; if ($index -ge $remaining.Count) { throw '--namespace requires a value.' }; $namespace=$remaining[$index] }
                default { if ($remaining[$index].StartsWith('-') -or $name) { throw "Unexpected argument: $($remaining[$index])" }; $name=$remaining[$index] }
            }
        }
        if (-not $name) { throw "$command requires a name." }
        $leaf = ($name -split '[/\\]')[-1]
        $prefix = $name.Substring(0,$name.Length-$leaf.Length)
        $plans = @()
        switch ($command) {
            'make:controller' {
                if (-not $leaf.EndsWith('Controller',[StringComparison]::Ordinal)) { $leaf += 'Controller' }
                $members = ''
                if ($resource) {
                    $members = @'
        [HttpGet]
        public IActionResult Index() => StatusCode(StatusCodes.Status501NotImplemented);

        [HttpGet("{id:int}")]
        public IActionResult Show(int id) => StatusCode(StatusCodes.Status501NotImplemented);

        [HttpPost]
        public IActionResult Store([FromBody] object request) => StatusCode(StatusCodes.Status501NotImplemented);

        [HttpPut("{id:int}")]
        public IActionResult Update(int id, [FromBody] object request) => StatusCode(StatusCodes.Status501NotImplemented);

        [HttpDelete("{id:int}")]
        public IActionResult Destroy(int id) => StatusCode(StatusCodes.Status501NotImplemented);
'@
                }
                $plans += New-DnetSourcePlan $project 'Controllers' ($prefix+$leaf) "class $leaf : ControllerBase" $members "using Microsoft.AspNetCore.Http;`r`nusing Microsoft.AspNetCore.Mvc;" "    [ApiController]`r`n    [Route(`"api/[controller]`")]" $namespace
            }
            'make:class' { $plans += New-DnetSourcePlan $project '' $name "class $leaf" '' '' '' $namespace }
            'make:model' { $folder=Get-DnetFolder $project @('Models','Entity','Entities'); $plans += New-DnetSourcePlan $project $folder $name "class $leaf" '' '' '' $namespace }
            'make:dto' { if ($leaf -notmatch 'Dto$') { $leaf+='Dto' }; $folder=Get-DnetFolder $project @('DTOs','Dtos'); $plans += New-DnetSourcePlan $project $folder ($prefix+$leaf) "class $leaf" '' '' '' $namespace }
            'make:enum' { $plans += New-DnetSourcePlan $project 'Enums' $name "enum $leaf" '' '' '' $namespace }
            'make:interface' { if ($leaf -cnotmatch '^I[A-Z]') { $leaf='I'+$leaf }; $folder=Get-DnetFolder $project @('Interfaces','Interface'); $plans += New-DnetSourcePlan $project $folder ($prefix+$leaf) "interface $leaf" '' '' '' $namespace }
            'make:service' {
                if (-not $leaf.EndsWith('Service',[StringComparison]::Ordinal)) { $leaf+='Service' }
                $serviceFolder=Get-DnetFolder $project @('Services','Service')
                $baseType=''; $usings=''
                if ($withInterface) {
                    $interfaceFolder=Get-DnetFolder $project @('Interfaces','Interface')
                    $interfacePlan=New-DnetSourcePlan $project $interfaceFolder ($prefix+'I'+$leaf) "interface I$leaf" '' '' '' $namespace
                    $plans += $interfacePlan
                    $baseType=" : I$leaf"; $usings="using $($interfacePlan.Namespace);"
                }
                $plans += New-DnetSourcePlan $project $serviceFolder ($prefix+$leaf) "class $leaf$baseType" '' $usings '' $namespace
            }
        }
        Write-DnetSources $project $plans
        return
    }
    $extra = @($remaining.ToArray())
    $solution = $project.Path
    if (-not $projectPath) { $solution = Get-DnetSolution $project }
    $nativeArgs = @()
    switch ($command) {
        'serve' { $nativeArgs=@('watch','--project',$project.Path,'run')+$extra }
        'run' { $nativeArgs=@('run','--project',$project.Path)+$extra }
        'build' { $nativeArgs=@('build',$solution)+$extra }
        'restore' { $nativeArgs=@('restore',$solution)+$extra }
        'clean' { $nativeArgs=@('clean',$solution)+$extra }
        'format' { $nativeArgs=@('format',$solution)+$extra }
        'test' {
            $target=$project.Path
            if (-not $projectPath -and -not $project.Test) {
                $tests=@(Get-DnetProjects $project.Directory | Where-Object { $_.Name -match '\.Tests\.csproj$' })
                if ($tests.Count -eq 1) { $target=$tests[0].FullName }
                else { throw 'Select a test project with --project PATH (no unique *.Tests.csproj found).' }
            }
            $nativeArgs=@('test',$target)+$extra
        }
        'package:add' { if (-not $extra.Count) { throw 'Use dnet package:add PackageName.' }; $nativeArgs=@('add',$project.Path,'package')+$extra }
        'make:migration' { if (-not $extra.Count -or $extra[0].StartsWith('-')) { throw 'Use dnet make:migration MigrationName.' }; $nativeArgs=@('ef','migrations','add')+$extra+@('--project',$project.Path) }
        'migrate' { $nativeArgs=@('ef','database','update')+$extra+@('--project',$project.Path) }
        'migrate:status' { $nativeArgs=@('ef','migrations','list')+$extra+@('--project',$project.Path) }
        'migrate:rollback' { if (-not $extra.Count -or $extra[0].StartsWith('-')) { throw 'Use dnet migrate:rollback MigrationName (or 0 to revert all).' }; $nativeArgs=@('ef','database','update')+$extra+@('--project',$project.Path) }
        'db:context' { $nativeArgs=@('ef','dbcontext','list')+$extra+@('--project',$project.Path) }
    }
    Invoke-DnetDotnet $project.Directory $nativeArgs
}

function dnet {
    $global:LASTEXITCODE = 0
    try { Invoke-Dnet -Arguments @($args) }
    catch { if (-not $global:LASTEXITCODE) { $global:LASTEXITCODE=1 }; Write-Error -Message $_.Exception.Message -ErrorAction Continue }
}

$script:DnetCommandNames = @('list','version','make:controller','make:class','make:model','make:dto','make:service','make:interface','make:enum','make:migration','serve','run','build','test','restore','clean','format','package:add','migrate','migrate:status','migrate:rollback','db:context')
if ((Get-Command Register-ArgumentCompleter -ErrorAction SilentlyContinue).Parameters.ContainsKey('Native')) {
    Register-ArgumentCompleter -Native -CommandName dnet -ScriptBlock {
        param($wordToComplete,$commandAst,$cursorPosition)
        foreach ($name in $script:DnetCommandNames) {
            if ($name -like "$wordToComplete*") { [Management.Automation.CompletionResult]::new($name,$name,'ParameterValue',$name) }
        }
    }
} else {
    Register-ArgumentCompleter -CommandName dnet -ScriptBlock {
        param($commandName,$parameterName,$wordToComplete,$commandAst,$fakeBoundParameters)
        foreach ($name in $script:DnetCommandNames) {
            if ($name -like "$wordToComplete*") { New-Object Management.Automation.CompletionResult($name,$name,'ParameterValue',$name) }
        }
    }
}
