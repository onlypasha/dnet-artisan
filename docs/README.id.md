# dnet-artisan

Perintah bergaya Laravel Artisan untuk .NET, langsung dari terminal PowerShell.
Bisa digunakan di Zed, VS Code, maupun terminal PowerShell lainnya.

## Instalasi

### Linux: Bash/Zsh

Pasang PowerShell 7 (`pwsh`) dan .NET SDK terlebih dahulu. Dari folder repository:

```sh
sh install.sh
export PATH="$HOME/.local/bin:$PATH"
dnet --version
dnet make:controller Product --resource
```

Perintah `dnet` bisa langsung dipakai di Bash/Zsh tanpa masuk ke shell PowerShell.
Mesinnya tetap membutuhkan `pwsh`. Installer tidak memakai `sudo` atau mengubah
profil shell. Lokasi launcher: `~/.local/bin/dnet`; lokasi mesin mengikuti
`XDG_DATA_HOME`, atau `~/.local/share/dnet-artisan/cli` secara default.

Untuk prefix sendiri, gunakan `sh install.sh --prefix "$HOME/tools"` lalu
tambahkan `$HOME/tools/bin` ke PATH. Lihat [panduan utama](../README.md).

### Windows / PowerShell

Jalankan dari folder repository:

```powershell
./install.ps1
```

Buka terminal **PowerShell baru**, masuk ke folder proyek .NET, lalu:

```powershell
dnet list
dnet make:controller Product --resource
dnet make:class Helpers/DateHelper
dnet make:model Product
dnet make:dto CreateProduct
dnet make:service Payment --interface
dnet make:enum OrderStatus
dnet serve
dnet build
dnet test
```

Windows PowerShell 5.1 dan PowerShell 7 didukung; Linux/macOS memerlukan
PowerShell 7. Versi awal ini berupa helper PowerShell, belum .NET global tool.
Installer mempertahankan isi profil lama dan membuat cadangannya. Tidak perlu
hak administrator dan kebijakan eksekusi PowerShell tidak diubah.

## Folder dan namespace

Folder yang sudah ada, seperti `Entity`, `Service`, dan `Interface`, digunakan
kembali. Proyek baru memakai `Models`, `Services`, dan `Interfaces`. Namespace
mengikuti `RootNamespace` atau nama proyek, termasuk subfolder yang diminta.

```powershell
dnet make:controller Admin/Report
dnet make:class Clock --namespace Company.Product.Helpers
dnet make:class Clock --project ./src/Api/Api.csproj
```

File lama tidak pernah ditimpa. Controller `--resource` masih berupa kerangka
CRUD dan mengembalikan HTTP 501 sampai implementasinya diisi. Model belum
otomatis menjadi tabel/DbSet; service belum otomatis didaftarkan di `Program.cs`.

## Entity Framework

```powershell
dnet make:migration AddProducts
dnet migrate:status
dnet migrate
dnet migrate:rollback NamaMigrationSebelumnya
```

Perintah ini memerlukan `dotnet-ef` dan `Microsoft.EntityFrameworkCore.Design`.
`dnet migrate` benar-benar memperbarui database sesuai konfigurasi aplikasi.
Rollback selalu memerlukan migration tujuan; `0` berarti sebelum migration
pertama. Instalasi dan tes helper tidak menjalankan migration pada database.

## Menghapus instalasi

Instalasi shell Linux:

```sh
sh uninstall.sh
# Jika memakai prefix sendiri:
sh uninstall.sh --prefix "$HOME/tools"
```

Instalasi profil PowerShell:

```powershell
./uninstall.ps1
```

Loader dan helper dihapus, isi profil lain dan cadangan tetap dipertahankan.
File C# yang pernah dibuat tidak dihapus. Lihat [panduan utama](../README.md)
dan [referensi perintah](commands.md) untuk opsi lengkap.
