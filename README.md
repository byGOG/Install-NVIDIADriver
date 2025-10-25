# Install-NVIDIADriver

NVIDIA App'i güncel sürümüyle otomatik indirip sessiz kurulum yapan bir PowerShell betiği eklendi: `Install-NVIDIAApp.ps1`.

Kullanım (PowerShell):

- En basit kullanım: `./Install-NVIDIAApp.ps1`
- Yalnız indirmek için: `./Install-NVIDIAApp.ps1 -DownloadOnly`
- İndirme klasörünü değiştirmek için: `./Install-NVIDIAApp.ps1 -OutDir 'C:\\Kurulumlar'`
- Sessiz parametreyi değiştirmek için: `./Install-NVIDIAApp.ps1 -SilentArgs '/S'`
- TR aynası yerine orijinal alan adını kullanmak için: `./Install-NVIDIAApp.ps1 -ForceUsMirror`

Notlar:

- Betik, en güncel indirme bağlantısını `nvidia.com` üzerindeki NVIDIA App sayfasından dinamik olarak bulur ve sürüm numarası otomatik tespit edilir.
- Varsayılan olarak TR indirme aynası (`tr.download.nvidia.com`) tercih edilir; erişilemezse otomatik olarak orijinal bağlantı kullanılır.
- Sessiz kurulum argümanı paketleyiciye göre değişebilir. Varsayılan `/S` genellikle yeterlidir; gerekirse `-SilentArgs` ile özelleştirin.

Hızlı Çalıştır (tek satır, irm | iex):

- `irm https://raw.githubusercontent.com/byGOG/Install-NVIDIADriver/main/Install-NVIDIAApp.ps1 | iex`

Gerekirse geçici olarak çalıştırma ilkesi atlamak için:

- `powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/byGOG/Install-NVIDIADriver/main/Install-NVIDIAApp.ps1 | iex"`
