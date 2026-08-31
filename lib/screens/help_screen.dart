import 'package:flutter/material.dart';
import 'package:keisan/constants/support_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import '../services/data_export_service.dart';
import '../services/data_import_service.dart';
import '../services/device_auth_service.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  Map<String, dynamic>? _userAppInfo;
  bool _loadingAppInfo = true;

  @override
  void initState() {
    super.initState();
    _loadUserAppInfo();
  }

  Future<void> _loadUserAppInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final appInfo = await DeviceAuthService().getUserRegistrationInfo();
        if (mounted) {
          setState(() {
            _userAppInfo = appInfo;
            _loadingAppInfo = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingAppInfo = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load user app info: $e');
      if (mounted) {
        setState(() {
          _loadingAppInfo = false;
        });
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> helpItems = [
      {
        'title': 'Yasal Uyarı',
        'description':
            'Bu uygulama, yalnızca kullanıcıya tahmini maaş hesaplamaları sunmak amacıyla hazırlanmıştır. Uygulama, herhangi bir resmi kurum, kuruluş veya şirket ile doğrudan ya da dolaylı olarak bağlantılı değildir, bu kurumlar tarafından onaylanmamış veya desteklenmemiştir. Yapılan hesaplamalar yaklaşık değerler olup, çeşitli varsayımlar ve genel bilgiler temel alınarak oluşturulmuştur. Bu nedenle uygulama tarafından sağlanan bilgiler, kesin ve bağlayıcı sonuçlar içermez.\n\n'
            'Kullanıcılar, bu uygulamada sunulan verileri resmi işlemler, finansal planlama, iş sözleşmeleri veya herhangi bir hukuki karar için dayanak olarak kullanmamalıdır. Gerçek maaş tutarları ve diğer resmi bilgiler için ilgili kurum veya uzmanlardan doğrudan bilgi alınması tavsiye edilir.\n\n'
            'Uygulama geliştiricisi, bu uygulamada sunulan bilgilerin kullanımından doğabilecek doğrudan veya dolaylı herhangi bir zarar veya kayıptan sorumlu tutulamaz.',
      },
      {
        'title': '1. Roster Yükleme ve Analiz',
        'description':
            'Ana ekrandan "Roster Yükle" butonuna tıklayın ve ICS formatındaki roster dosyanızı seçin.\n\n'
            '• Menüde beliren "Analizi Tamamla" butonuna basın\n'
            '• Roster özetiniz karşınıda belirecektir, "Roster Dökümleri" nde geçmişe dönük roster kayıtlarınızı görebilirsiniz.\n'
      },
      {
        'title': '2. Maaş Bilgileri Girişi',
        'description':
            '"Hesapla" bölümünde:\n\n'
            '• Önce base maaşınızı en üstte bulunan buton ile belirleyiniz.\n'
            'Sistem otomatik olarak taban maaşınızı hesaplayacaktır. Bu işlemi bir kez gerçekleştirmeniz yeterlidir.\n\n'
            'Ayrıca:\n'
            '• Önceki tarihlere ait hesap yapmak istiyorsanız dönem seçimi yapın ve hesapla butununa basın.\n'
            '• Euro kurunu güncelleyin\n'
            '• 6. gün uçuşları programınızda belirtilmiş olsada uygulama bunu hesaba katmayacaktır. Manuel olarak kaç gün olduğunu girmeniz gereklidir. Aynı durum "off duty" günleri için de geçerlidir.\n'
      },
      {
        'title': '3. Komisyon İşlemleri',
        'description':
            'Komisyonlar bölümünde:\n\n'
            '• Yeni komisyon ekleyebilirsiniz. "Komisyon Giriniz" kısmından takvim üzerine tıklayarak tutar girdikten sonra, şayet 5 kişi iseniz 5 kişi kutucuğunu işaretleyiniz\n'
            '• "İç Hat Uçuşları" için komisyon girişi yapıyorsanız, 5 kişi kutucuğunun altındaki "İç Hat Uçuşları" seçeneğini işaretleyiniz. İç hat komisyonları TL maaşınız hesaplandıktan sonra TL maaşınıza eklenir.\n'
            '• İstediğiniz herhangi bir aydaki olması gereken komisyon tutarının yaptığınız girdilere göre ne kadar olması gerektiğini dönem komisyonları sayfasında en üst kısımda  "Dönem Seçiniz" e tıklayarak öğrenebilirsiniz.\n'
            '• "Takvim üzerinden yanlış giriş yapıldığında, tekrar aynı güne tıklayıp doğru miktarı girerek düzeltme yapabilirsiniz. Silmek isterseniz "0" girerek komisyonu sıfırlayabilirsiniz.\n'
            '• "Girdi Geçmişi" sayfasında seçtiğiniz ay içinde girmiş olduğunuz komisyonları görüntüleyebilirsiniz.\n'
            'ÖNEMLİ: Hesaplama kısmında seçilen roster dönemi için o döneme ait komisyon toplamı otomatik olarak hesaplamaya dahil edilir.\n',
      },
      {
        'title': '4. Roster Takvimi',
        'description':
            '"Roster Takvimi" ekranı, yükleyip kaydettiğiniz roster\'daki etkinlikleri takvim formatında gösterir. Veriler, roster dosyanızdaki ICS/analiz verilerinden otomatik olarak oluşturulur.\n\n'
            'Takvimin üzerinde bulunan özet şeridinde o ay için:\n'
            '• ✈️ FLY: Uçuş günü sayısı\n'
            '• 🟡 SB: Stand-by günü sayısı\n'
            '• 🟢 OFF: İzin (off) günü sayısı\n'
            '• ⏱️ DUTY: Toplam görev/fiili mesai süresi\n\n'
            '• Bir güne dokunarak o günün etkinliklerini detaylı görebilirsiniz (check-in, uçuş bacakları, release).\n'
            '• Layover (konaklamalı) uçuşlarda otel, transfer ve ödeme tutarı (€) bilgileri ayrı bir kart olarak gösterilir.\n'
            '• Üstteki oklarla ay, format butonlarıyla hafta/ay görünümü arasında geçiş yapabilirsiniz.\n'
            '• Takvimin boş görünmesi halinde önce "Roster Yükle" menüsünden bir roster analiz edip kaydetmeniz gerekir.\n',
      },
      {
        'title': '5. Geçmiş Kayıtlar',
        'description':
            'Uygulama üç farklı geçmiş kaydı tutar:\n\n'
            '• Roster Geçmişi: Her dönem için PDF analiz sonuçları\n'
            '• Komisyon Geçmişi: Tarih bazlı komisyon kayıtları\n'
            '• Maaş Geçmişi: Dönem bazlı maaş kayıtları\n\n'
            'Bu kayıtlara ilgili menülerden ulaşabilir, görüntüleyebilir ve karşılaştırma yapabilirsiniz.',
      },
      {
        'title': '6. İstatistikler',
        'description':
            'İstatistikler, her roster dönemi için tarih olarak en son kaydedilen roster bilgileri kullanılarak oluşturulur:\n\n'
            '• Şayet roster periyotlarında herhangi ay için gün olarak farklı tarihlerde roster bilgileri varsa uygulama iki farklı roster olarak algılayıp istatistiklerde iki kez görünmesine sebep olacaktır \n'
            ' Örneğin 28Jun25-31Jul25 ve 01Jul25-31Jul25 tarihleri için iki farklı roster kaydı analiz etmişseniz, istatistikler bunu iki farklı kayıt olarak oluşturacaktır. İstemediğiniz kaydı "Roster Dökümleri ve Geçmiş Maaşlarım" sayfasından silerek düzeltebilirsiniz.\n'
            '• "Tablo Seçenekleri" menüsünden tabloda görünmesini istediğiniz veya istemediğiniz alanları seçebilirsiniz.\n'
            '• Tablonuzu istediğiniz gibi şekillendirtikten sonra en allta bulunan "Tabloyu Excel Olarak İndir" butonuna tıklayarak dışa aktarabilirsiniz.\n'
            '• Maaş İstatistikleri: Dönem bazlı maaş kayıtları\n\n'
            'Bu kayıtlara ilgili menülerden ulaşabilir, görüntüleyebilir ve karşılaştırma yapabilirsiniz.',
      },
      {
        'title': '7. Uygulama Yönetimi',
        'description':
            'Uygulama güvenliği için:\n\n'
            '• Her e-posta adresi yalnızca tek bir uygulama numarası ile kullanılabilir.\n'
            '• Uygulamanız admin onayı gerektirir ve onaylanana kadar sınırlı erişime sahip olursunuz.\n'
            '• Uygulama numaranız yukarıda "Uygulama Numarası (User ID)" bölümünde görüntülenir.\n'
            '• Farklı bir cihazda aynı hesapla giriş yapmak için önce mevcut uygulama kaydınızı silmeniz gerekir.\n'
            '• Uygulama kaydınızı yönetmek için Profil sayfasındaki "Uygulama Yönetimi" butonunu kullanabilirsiniz.\n'
            '• Uygulama içerindeki her türlü işlenen bilgi telefonunuzda saklanır ve üçüncü taraflarla paylaşılmaz. Admin veya herhangi bir kurumun bu bilgilere kesinlikle erişimi yoktur!\n'
            '• Uygulama kaydını sildiğinizde, uygulamadan otomatik olarak çıkış yaparsınız.\n\n'
            'Bu güvenlik önlemi, hesabınızın izinsiz kullanımını engellemeye yardımcı olur.',
      },
      {
        'title': '8. Veri Yedekleme ve Geri Yükleme',
        'description':
            'Uygulamayı kaldırdığınızda verilerinizi kaybetmemek için:\n\n'
            '• Aşağıdaki "Veri Yedekleme" bölümünden verilerinizi yedekleyebilirsiniz\n'
            '• Tüm verileriniz (roster geçmişi, maaş hesaplamaları, komisyonlar) tek dosyada yedeklenir\n'
            '• Yedekleme dosyasını güvenli bir yerde saklayın (Google Drive, iCloud vb.)\n'
            '• Uygulamayı yeniden yükledikten sonra yedekleme dosyanızı geri yükleyebilirsiniz\n\n'
            'Öneriler:\n'
            '• Düzenli olarak yedekleme yapın\n'
            '• Uygulama güncellemelerinden önce yedek alın\n'
            '• Yedekleme dosyalarını tarih ile adlandırın',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Kullanım Klavuzu',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFED6C02),
            fontSize: 24,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(Icons.home, size: 22, color: Colors.orange[300]),
            tooltip: 'Ana Sayfa',
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromRGBO(21, 123, 163, 1.0),
              Color.fromRGBO(146, 74, 26, 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
            ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // App ID Card
                Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color: const Color.fromRGBO(42, 45, 62, 0.7),
                  child: ListTile(
                    leading: Icon(
                      _loadingAppInfo
                          ? Icons.hourglass_empty
                          : (_userAppInfo?['isApproved'] == true
                              ? Icons.verified_user
                              : Icons.pending),
                      color: _loadingAppInfo
                          ? Colors.grey
                          : (_userAppInfo?['isApproved'] == true
                              ? Colors.green
                              : Colors.orange),
                    ),
                    title: const Text(
                      'Uygulama Numarası (User ID)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFFFA726),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingAppInfo
                              ? 'Yükleniyor...'
                              : (_userAppInfo?['appId'] ?? 'Mevcut değil'),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                        if (!_loadingAppInfo && _userAppInfo != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Durum: ${_userAppInfo!['isApproved'] == true ? "Onaylandı ✅" : "Onay Bekliyor ⏳"}',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: _userAppInfo!['isApproved'] == true
                                  ? Colors.green[300]
                                  : Colors.orange[300],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (_userAppInfo!['email'] != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'E-posta: ${_userAppInfo!['email']}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.copy, color: Colors.white70),
                      tooltip: 'Kopyala',
                      onPressed: () {
                        final appId = _userAppInfo?['appId'] ?? 'Mevcut değil';
                        Clipboard.setData(ClipboardData(text: appId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              appId != 'Mevcut değil'
                                  ? 'Uygulama Numarası kopyalandı'
                                  : 'Kopyalanacak numara bulunamadı'
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // Help items
                ...helpItems.map((item) => Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16.0),
                  color: const Color.fromRGBO(42, 45, 62, 0.7),
                  child: ExpansionTile(
                    title: Text(
                      item['title']!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFFFFA726),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: const BoxDecoration(
                          color: Color.fromRGBO(255, 255, 255, 0.1),
                        ),
                        child: Text(
                          item['description']!,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
               ),
                
                // Data Backup Section
                const SizedBox(height: 20),
                Card(
                  elevation: 6,
                  margin: const EdgeInsets.only(bottom: 100),
                  color: const Color.fromRGBO(42, 45, 62, 0.9),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.backup,
                              color: Color(0xFFED6C02),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Veri Yedekleme',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFFED6C02),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Verilerinizi kaybetmemek için düzenli yedekleme yapın:',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Export buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => DataExportService.exportAllData(context),
                            icon: const Icon(Icons.download, color: Colors.white),
                            label: const Text(
                              'Tüm Verileri Yedekle',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4CAF50),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => DataImportService.importDataFromBackup(context),
                            icon: const Icon(Icons.upload, color: Colors.white),
                            label: const Text(
                              'Yedekten Geri Yükle',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9800),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                        
                        const Text(
                          'Ayrı dosyalar olarak dışa aktar:',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => DataExportService.exportSalaryHistory(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2196F3),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Maaş Geçmişi',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => DataExportService.exportCommissionHistory(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF9C27B0),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Komisyonlar',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => DataExportService.exportRosterHistory(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5722),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                child: const Text(
                                  'Roster Geçmişi',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromARGB(51, 33, 150, 243),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '💡 İpucu: Yedekleme dosyalarını Google Drive, iCloud veya başka bir bulut depolama hizmetinde saklayarak güvenliğini sağlayın.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.fromRGBO(255, 255, 255, 0.2),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.contact_support,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              backgroundColor: const Color.fromRGBO(
                                42,
                                45,
                                62,
                                0.95,
                              ),
                              title: const Text(
                                'İletişim',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFED6C02),
                                ),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sorularınız için:',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    SupportInfo.supportEmail,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Color(0xFFFFA726),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Destek sayfası:',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () => _launchUrl(SupportInfo.supportPageUrl),
                                    child: const Text(
                                      'Destek Sayfasını Aç',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        color: Color(0xFFFFA726),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Versiyon: ${SupportInfo.version}',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => _launchUrl(SupportInfo.supportPageUrl),
                                  child: const Text(
                                    'Destek Sayfası',
                                    style: TextStyle(color: Color(0xFFFFA726)),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Tamam',
                                    style: TextStyle(color: Color(0xFFFFA726)),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
