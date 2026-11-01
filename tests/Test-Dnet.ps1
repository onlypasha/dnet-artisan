param([switch]$SkipBuild,[switch]$KeepArtifacts)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../src/Dnet.ps1')
$artifactsRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.artifacts'))
$fixtureRoot = Join-Path $artifactsRoot ('dnet-artisan-tests-' + [guid]::NewGuid().ToString('N'))
$savedEnvironment=@{}
foreach ($name in @('DOTNET_CLI_HOME','DOTNET_SKIP_FIRST_TIME_EXPERIENCE','DOTNET_GENERATE_ASPNET_CERTIFICATE','DOTNET_CLI_TELEMETRY_OPTOUT','DOTNET_ADD_GLOBAL_TOOLS_TO_PATH','NUGET_PACKAGES','NUGET_HTTP_CACHE_PATH','NUGET_SCRATCH','NUGET_PLUGINS_CACHE_PATH')) {
    $savedEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
}
$apiDir = Join-Path $fixtureRoot 'Api with spaces'
[void][IO.Directory]::CreateDirectory($apiDir)
foreach ($folder in @('Entity','DTOs','Service','Interface')) { [void][IO.Directory]::CreateDirectory((Join-Path $apiDir $folder)) }
@'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <OutputType>Library</OutputType>
    <RootNamespace>DnetSmoke.Custom</RootNamespace>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
'@ | Set-Content -LiteralPath (Join-Path $apiDir 'Smoke.csproj')
'<Solution><Project Path="Api with spaces/Smoke.csproj" /></Solution>' | Set-Content -LiteralPath (Join-Path $fixtureRoot 'Smoke.slnx')
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Assert-Throws([scriptblock]$Action,[string]$Pattern) {
    $caught=$null
    try { & $Action } catch { $caught=$_.Exception.Message }
    if (-not $caught -or $caught -notmatch $Pattern) { throw "Expected '$Pattern', got '$caught'." }
}
Push-Location -LiteralPath $fixtureRoot
try {
    Invoke-Dnet @('make:controller','Admin/Report','--resource')
    Invoke-Dnet @('make:controller','Empty')
    Invoke-Dnet @('make:class','Helpers/Clock')
    Invoke-Dnet @('make:model','Customer')
    Invoke-Dnet @('make:dto','CreateCustomer')
    Invoke-Dnet @('make:service','Billing','--interface')
    Invoke-Dnet @('make:service','Admin/Export','--interface')
    Invoke-Dnet @('make:interface','IClock')
    Invoke-Dnet @('make:enum','OrderStatus')
    Invoke-Dnet @('make:class','Explicit','--namespace','My.Custom.Namespace')
    Assert (Test-Path -LiteralPath (Join-Path $apiDir 'Entity/Customer.cs')) 'Existing Entity folder was not respected.'
    Assert (Test-Path -LiteralPath (Join-Path $apiDir 'Service/BillingService.cs')) 'Existing Service folder was not respected.'
    Assert (([IO.File]::ReadAllText((Join-Path $apiDir 'Controllers/Admin/ReportController.cs'))) -match 'namespace DnetSmoke.Custom.Controllers.Admin') 'RootNamespace or nested namespace is incorrect.'
    $original=[IO.File]::ReadAllText((Join-Path $apiDir 'Helpers/Clock.cs'))
    Assert-Throws { Invoke-Dnet @('make:class','Helpers/Clock') } 'already exists'
    Assert ([IO.File]::ReadAllText((Join-Path $apiDir 'Helpers/Clock.cs')) -ceq $original) 'Collision modified an existing file.'
    Invoke-Dnet @('make:interface','IConflictService')
    Assert-Throws { Invoke-Dnet @('make:service','Conflict','--interface') } 'already exists'
    Assert (-not (Test-Path -LiteralPath (Join-Path $apiDir 'Service/ConflictService.cs'))) 'Service/interface collision left a partial pair.'
    Assert-Throws { Invoke-Dnet @('make:class','../Outside') } 'traversal'
    Assert-Throws { Invoke-Dnet @('make:class','C:\Outside') } 'traversal'
    Assert-Throws { Invoke-Dnet @('make:class','class') } 'identifier'
    Assert-Throws { Invoke-Dnet @('make:class','Bad','--unknown') } 'Unexpected'
    Assert-Throws { Invoke-Dnet @('make:controller') } 'requires a name'
    Assert-Throws { Invoke-Dnet @('make:class','Extension.cs') } 'extensions'
    Push-Location -LiteralPath (Join-Path $apiDir 'Controllers/Admin')
    try { Assert ((Resolve-DnetProject).Path -eq (Join-Path $apiDir 'Smoke.csproj')) 'Nested working directory resolution failed.' }
    finally { Pop-Location }
    $ambiguousDir=Join-Path $fixtureRoot 'Ambiguous'
    foreach ($child in @('First','Second')) {
        $childDir=Join-Path $ambiguousDir $child
        [void][IO.Directory]::CreateDirectory($childDir)
        '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>' | Set-Content -LiteralPath (Join-Path $childDir "$child.csproj")
    }
    Assert-Throws { Resolve-DnetProject $ambiguousDir } 'unique'
    Assert ((Resolve-DnetProject (Join-Path $ambiguousDir 'First/First.csproj')).Path.EndsWith('First.csproj')) 'Explicit project selection failed.'
    $env:DOTNET_CLI_HOME=Join-Path $fixtureRoot 'dotnet-cli-home'
    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1'
    $env:DOTNET_GENERATE_ASPNET_CERTIFICATE='false'
    $env:DOTNET_CLI_TELEMETRY_OPTOUT='1'
    $env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH='false'
    $env:NUGET_PACKAGES=Join-Path $fixtureRoot '.nuget/packages'
    $env:NUGET_HTTP_CACHE_PATH=Join-Path $fixtureRoot '.nuget/http-cache'
    $env:NUGET_SCRATCH=Join-Path $fixtureRoot '.nuget/scratch'
    $env:NUGET_PLUGINS_CACHE_PATH=Join-Path $fixtureRoot '.nuget/plugin-cache'
    if (-not $SkipBuild) {
        & dotnet build (Join-Path $apiDir 'Smoke.csproj') --nologo --ignore-failed-sources -p:NuGetAudit=false
        Assert ($LASTEXITCODE -eq 0) 'Generated C# did not compile.'
    }
    function Invoke-DnetDotnet { param([string]$Directory,[string[]]$Arguments) $script:Captured=[pscustomobject]@{Directory=$Directory;Arguments=$Arguments} }
    Invoke-Dnet @('serve','--urls','http://localhost:5050')
    Assert (($Captured.Arguments -join '|') -eq "watch|--project|$(Join-Path $apiDir 'Smoke.csproj')|run|--urls|http://localhost:5050") 'Serve arguments were not preserved.'
    Invoke-Dnet @('run','--','--project','application option')
    Assert (($Captured.Arguments -join '|') -eq "run|--project|$(Join-Path $apiDir 'Smoke.csproj')|--|--project|application option") 'App arguments after -- were changed.'
    Invoke-Dnet @('build','--project',(Join-Path $apiDir 'Smoke.csproj'))
    Assert ($Captured.Arguments[1] -eq (Join-Path $apiDir 'Smoke.csproj')) 'Explicit build target was not respected.'
    Invoke-Dnet @('make:migration','AddCustomers','--context','AppDbContext')
    Assert (($Captured.Arguments -join '|') -eq "ef|migrations|add|AddCustomers|--context|AppDbContext|--project|$(Join-Path $apiDir 'Smoke.csproj')") 'EF migration forwarding is incorrect.'
    Invoke-Dnet @('migrate:rollback','PreviousMigration')
    Assert (($Captured.Arguments -join '|') -eq "ef|database|update|PreviousMigration|--project|$(Join-Path $apiDir 'Smoke.csproj')") 'Rollback target was not preserved.'
    Assert-Throws { Invoke-Dnet @('migrate:rollback') } 'MigrationName'
    Invoke-Dnet @('package:add','Some.Package','--version','1.2.3')
    Assert (($Captured.Arguments -join '|') -eq "add|$(Join-Path $apiDir 'Smoke.csproj')|package|Some.Package|--version|1.2.3") 'Package options were not preserved.'
    Assert-Throws { Invoke-Dnet @('test') } 'test project'
    $testDir=Join-Path $apiDir 'tests/Smoke.Tests'
    [void][IO.Directory]::CreateDirectory($testDir)
    '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><IsTestProject>true</IsTestProject></PropertyGroup></Project>' | Set-Content -LiteralPath (Join-Path $testDir 'Smoke.Tests.csproj')
    Invoke-Dnet @('test','--no-restore')
    Assert ($Captured.Arguments[1] -eq (Join-Path $testDir 'Smoke.Tests.csproj')) 'Unit test project discovery failed.'
    $helpOutput=dnet list | Out-String
    Assert ($helpOutput -match 'make:controller') 'Public dnet function is not callable.'
    $completion=TabExpansion2 'dnet make:con' 13
    Assert ($completion.CompletionMatches.CompletionText -contains 'make:controller') 'Command tab completion failed.'
    Assert ((dnet --version) -eq "dnet-artisan $(([IO.File]::ReadAllText((Join-Path $PSScriptRoot '../VERSION'))).Trim())") 'Version metadata disagrees.'
    Write-Output 'PASS: generators, namespace/path selection, collisions, traversal, native argument forwarding, test discovery, completion, and version metadata.'
} finally {
    Pop-Location
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name,$savedEnvironment[$name],'Process') }
    if ($KeepArtifacts) { Write-Host "Artifacts retained: $fixtureRoot" }
    elseif (Test-Path -LiteralPath $fixtureRoot) {
        $absoluteFixture=[IO.Path]::GetFullPath($fixtureRoot)
        $tempRoot=$artifactsRoot.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
        if (-not $absoluteFixture.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($absoluteFixture) -notmatch '^dnet-artisan-tests-[a-f0-9]{32}$') { throw 'Unsafe test cleanup path.' }
        Remove-Item -LiteralPath $absoluteFixture -Recurse -Force
    }
}
