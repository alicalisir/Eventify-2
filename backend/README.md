# USER PROFILING & EVENT RECOMMENDATION SYSTEM

Sahte telemetri verilerinden kullanıcı profilleri çıkartıp, DBSCAN kümeleme ile benzer kullanıcıları gruplandırıp, event önerileri sunan sistem.

## Sistem Mimarisi

```
┌─────────────────────────────────────────────────────────────┐
│                    VERİ GİRİŞİ (CSV)                         │
├─────────────────────────────────────────────────────────────┤
│  • users.csv (konum)                                         │
│  • app_sessions.csv (uygulama kullanımı)                    │
│  • gps_pings.csv (GPS verileri)                             │
│  • daily_summary.csv (günlük özet)                          │
│  • user_places_summary.csv (ziyaret edilen mekanlar)        │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              USER PROFILING (user_profiling.py)             │
├─────────────────────────────────────────────────────────────┤
│  1. MEKAN ÖZELLIKLERI (6 feature)                           │
│     - home_ratio: evde geçen zaman oranı (0-1)             │
│     - social_ratio: sosyal mekanlar (0-1)                  │
│     - work_ratio: çalışma alanları (0-1)                   │
│     - outdoor_ratio: açık havada (0-1)                      │
│     - unique_places_count: yer sayısı                      │
│     - avg_time_per_place: ortalama kalış süresi             │
│                                                              │
│  2. MOBİLİTE ÖZELLIKLERI (2 feature)                        │
│     - daily_distance_km: günlük mesafe                      │
│     - movement_variance: hareketlilik varyansı              │
│                                                              │
│  3. ZAMAN ÖZELLIKLERI (2 feature)                           │
│     - night_usage_ratio: gece kullanım (21:00-06:00)       │
│     - weekend_activity_ratio: hafta sonu oranı              │
│                                                              │
│  4. APP ÖZELLIKLERI (3 feature)                             │
│     - social_app_ratio: sosyal uygulamalar                  │
│     - video_app_ratio: video uygulamaları                   │
│     - music_app_ratio: müzik uygulamaları                   │
│                                                              │
│  5. DAVRANIŞ ÖZELLIKLERI (2 feature)                        │
│     - session_count: toplam oturum sayısı                   │
│     - avg_session_duration: ortalama oturum süresi          │
│                                                              │
│  TOPLAM: 16 Feature                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│           NORMALIZASYON (StandardScaler)                     │
├─────────────────────────────────────────────────────────────┤
│  Tüm özellikleri 0 ortalama, 1 std'ye normalize et          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│          DBSCAN KÜMELEMİ (eps=0.8, min_samples=2)           │
├─────────────────────────────────────────────────────────────┤
│  Benzer kullanıcıları gruplandır (yoğunluk tabanlı)         │
│  Gürültü (noise) noktaları da tanımla                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│         VİZÜALİZASYON (PCA + Matplotlib)                    │
├─────────────────────────────────────────────────────────────┤
│  2D görselleştirme ve özelliklerin korelasyonu              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│    PERSONA MAPPING (cluster_persona_mapper.py)              │
├─────────────────────────────────────────────────────────────┤
│  12 Önceden Tanımlanmış Persona:                            │
│  • P001: Sosyal Medya Etkinliğe Tutkunu                     │
│  • P002: Aktif Gezgin                                       │
│  • P003: Gece Kuşu                                          │
│  • P004: Sabit Rutinli Kullanıcı                            │
│  • P005: Medya Tüketicisi                                   │
│  • P006: Teknoloji Meraklısı                                │
│  • P007: Kendini Geliştiren                                 │
│  • P008: Aile Odaklı                                        │
│  • P009: Minimal Cihaz Kullanıcı                            │
│  • P010: Sağlık & Fitness Tutkunu                           │
│  • P011: Shopping & Moda Tutkunu                            │
│  • P012: Dengeli Yaşamlı                                    │
│                                                              │
│  Mapping Yöntemi:                                           │
│  1. Cosine Similarity (vektör uzaklığı)                     │
│  2. Karakteristik Eşleşmesi (kurallar)                      │
│  3. Kombinlenmiş Skor (60% similarity + 40% rules)          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│      EVENT RECOMMENDATION (event_recommender.py)             │
├─────────────────────────────────────────────────────────────┤
│  Persona'ya uygun event'ler öner                             │
│  Her event için uygunluk skoru hesapla                      │
│  Top-3 event'i öner                                         │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                     ÇIKTI (CSV/PNG/JSON)                     │
├─────────────────────────────────────────────────────────────┤
│  • user_profiles.csv                                         │
│  • user_profiles_clustered.csv                              │
│  • clusters_visualization.png                               │
│  • user_profiles_with_personas.csv                          │
│  • cluster_persona_mapping.csv                              │
│  • mapping_analysis_report.json                             │
│  • event_recommendations.csv                                │
└─────────────────────────────────────────────────────────────┘
```

## Kurulum

```bash
# Dependencies kurması
pip install -r req.txt

# Veya manuel olarak
pip install pandas numpy scikit-learn matplotlib seaborn requests
```

## Kullanım

### Seçenek 1: Komple Pipeline (Önerilen)

```bash
python main_pipeline.py
```

Şunları yapacak:
1. Tüm CSV dosyalarından profil özelikleri çıkartır
2. Profilleri standardize eder
3. DBSCAN ile kümeleme yapar
4. Küme görsellendirmesini oluşturur
5. Event önerileri üretir

### Seçenek 2: Sadece Profilling

```python
from user_profiling import UserProfiler

profiler = UserProfiler(data_dir=".")
profiler.load_data()
profiler.extract_profiles()
profiler.normalize_features()
profiler.cluster_users(eps=0.8, min_samples=2)
profiler.visualize_clusters()
profiler.save_profiles("user_profiles.csv")
```

### Seçenek 3: Event Önerileri

```python
from event_recommender import EventRecommender

recommender = EventRecommender("user_profiles_clustered.csv")

# Bir kullanıcı için öneriler
recommendations = recommender.recommend_for_user("USER_ID")

# Tüm kullanıcılar için rapor
recommender.generate_report("event_recommendations.csv")
```

## Persona Tanımları

Sistem 12 adet önceden tanımlanmış user persona'sını kullanır. Her persona kendi karakteristik özellikleri ve event önerileriyle tanımlanmıştır.

### Persona Listesi

1. **P001_SOSYAL_MEDYA_ETKINLIGI** (Sosyal Medya Etkinliğe Tutkunu)
   - Sosyal uyg. oranı > 35%, Yüksek oturum sayısı
   - Events: Workshop, Networking, Content Creator Meetup

2. **P002_AKTIF_GEZGIN** (Aktif Gezgin)
   - Günlük mesafe > 2.5 km, Açık hava aktiviteleri
   - Events: Şehir Keşfi, Doğa Yürüyüşü, Adventure Sports

3. **P003_GECE_KUSU** (Gece Kuşu)
   - Gece kullanım > 35%, Hafta sonu aktivitesi yüksek
   - Events: Night Market, Gece Sinemasi, Müzik Konseri

4. **P004_STABIL_RUTINLI** (Sabit Rutinli)
   - Düşük hareketlilik (varyans), Belirli yerleri tercih
   - Events: Yoga, Meditasyon, Kişisel Gelişim

5. **P005_MEDYA_TUKETICI** (Medya Tüketicisi)
   - Video uyg. > 25%, Müzik uyg. > 10%
   - Events: Film Festival, Müzik Festivali, Workshop

6. **P006_TEKNOLOJI_MERAKLI** (Teknoloji Meraklısı)
   - Yüksek harita/nav. kullanımı, Yüksek hareketlilik
   - Events: Tech Konferansı, GIS Workshop, Dron Rekabeti

7. **P007_KENDINI_GELISTIR** (Kendini Geliştiren)
   - Oturum sayısı > 120, Yüksek oturum süresi
   - Events: Kariyer Programı, Yazı Workshop, Liderlik

8. **P008_AILE_ODAKLI** (Aile Odaklı)
   - Ev oranı > 35%, Hafta sonu aktiviteleri yüksek
   - Events: Aile Etkinlikleri, Çocuk Workshop, Komunite

9. **P009_MINIMAL_KULLANICI** (Minimal Cihaz Kullanıcı)
   - Düşük oturum sayısı < 50, Minimal sosyal app
   - Events: Basit Aktiviteler, Hızlı Workshop

10. **P010_SAGLIK_FITNES** (Sağlık & Fitness Tutkunu)
    - Yüksek movimento, Outdoor aktiviteler, Düşük gece
    - Events: Fitness Kulübü, Yoga Retreati, Marathon

11. **P011_SHOPPING_FASHIONISTA** (Shopping & Moda Tutkunu)
    - Yüksek oturum, Hafta sonu aktiviteleri, Günlük mesafe
    - Events: Fashion Show, Outlet Pazarı, Shopping Festival

12. **P012_BALANCED_LIFESTYLE** (Dengeli Yaşamlı)
    - Ev, sosyal, spor aktivitelerinde denge
    - Events: Mixed Activity Fest, Community Events

### Mapping Algoritması

```
Cluster → Persona Mapping Adımları:

1. Feature Normalizasyon
   - Cluster ve Persona vektörlerini standardize et

2. Benzerlik Hesaplaması (Cosine Similarity)
   - Euclidean uzayında iki vektör arasındaki açıyı hesapla
   - Sonuç: 0-1 arası benzerlik skoru

3. Karakteristik Eşleşmesi
   - Her feature'ın persona aralığında olup olmadığını kontrol et
   - Eşleşme oranı = (eşleşen feature sayısı) / (toplam feature sayısı)

4. Kombinlenmiş Skor
   - Final Score = (Benzerlik × 0.6) + (Karakteristik Eşleşme × 0.4)
   - En yüksek skora sahip persona atanır

5. Alternatif Persona'lar
   - Top-3 alternatif persona da hesaplanır
```

## Çıktı Dosyaları

### user_profiles.csv
Her kullanıcı + 16 profil özelliği

```csv
user_id,home_ratio,social_ratio,work_ratio,...
USER_001,0.45,0.20,0.15,...
```

### user_profiles_clustered.csv
Küme etiketi ile birlikte

```csv
user_id,...,cluster
USER_001,...,0
USER_002,...,1
```

### user_profiles_with_personas.csv
Persona tahmini ile birlikte

```csv
user_id,cluster,persona_id,persona_name,...
USER_001,0,P002,Aktif Gezgin,...
```

### cluster_persona_mapping.csv
Cluster → Persona mapping detayları

```csv
cluster_id,cluster_size,mapped_persona_id,mapped_persona_name,mapping_score,...
0,15,P002,Aktif Gezgin,0.823,...
```

### mapping_analysis_report.json
Detaylı analiz raporu (JSON formatında)

```json
{
  "cluster_0": {
    "mapped_persona": {"id": "P002", "name": "Aktif Gezgin"},
    "scores": {
      "combined_score": 0.823,
      "similarity_score": 0.856,
      "characteristic_match": 0.75
    },
    "cluster_size": 15,
    "alternatives": [...]
  }
}
```

### event_recommendations.csv
Her kullanıcı için top-3 event

```csv
user_id,rank,event_name,description,...
USER_001,1,"Şehir Keşif Turu",...
USER_001,2,"Doğa Yürüyüşü",...
```

### clusters_visualization.png
PCA ile 2D görselleştirme

### 1. user_profiles.csv
Her kullanıcı + 16 profil özelliği

```csv
user_id,home_ratio,social_ratio,work_ratio,outdoor_ratio,...
USER_001,0.45,0.20,0.15,0.10,...
```

### 2. user_profiles_clustered.csv
Küme etiketi ile birlikte

```csv
user_id,...,cluster
USER_001,...,0
USER_002,...,1
USER_003,...,-1  # gürültü
```

### 3. event_recommendations.csv
Her kullanıcı için top-3 event

```csv
user_id,rank,event_name,description,location,category,suitability_score
USER_001,1,"Sosyal Medya Workshop",...,0.95
USER_001,2,"Networking Event",...,0.90
USER_001,3,"Content Creator Meetup",...,0.92
```

### 4. clusters_visualization.png
2 grafiklı görselleştirme:
- Sol: DBSCAN kümeleme sonuçları (PCA)
- Sağ: Özellik korelasyonu (Night Usage vs Session Count)

## Parametre Ayarlaması

### DBSCAN (eps ve min_samples)

```python
profiler.cluster_users(eps=0.8, min_samples=2)
```

- **eps**: Yarıçap. Küçük = daha sıkı kümeler, daha fazla gürültü
  - 0.5: Çok sıkı (çok sayıda küme)
  - 0.8: Orta (normal)
  - 1.0+: Gevşek (büyük kümeler)

- **min_samples**: Minimum örnek sayısı
  - 2: 2 örnek bir küme oluşturabilir
  - 3-5: Daha güvenilir kümeler
  - Veri sayısına göre ayarla

### Event Kategorileri

`event_recommender.py` içinde `EVENTS` sözlüğünü düzenle:

```python
'SOSYAL_KULLANICI': {
    'characteristics': {
        'social_app_ratio': (0.3, 1.0),
        'session_count': (100, float('inf'))
    },
    'events': [ ... ]
}
```

## Profil Kategorileri

Otomatik atanır (`_categorize_user` fonksiyonunda):

1. **SOSYAL_KULLANICI**: social_app_ratio > 0.3
2. **AKTIF_MOBIL_KULLANICI**: daily_distance_km > 2.0
3. **GECE_KUSU**: night_usage_ratio > 0.3
4. **GUNLUK_RUTINLI**: düşük hareketlilik + yüksek avg_time_per_place
5. **MEDYA_TUKETICI**: video/music uygulamaları > 0.2
6. **KENDINI_GELISTIR**: session_count > 50

## Örnek Analiz

### Kullanıcı Profili Çıkartma

```python
user_id = "U_f742676feb"
profile = profiles[profiles['user_id'] == user_id].iloc[0]

print(f"Home Time: {profile['home_ratio']:.1%}")
print(f"Social Apps: {profile['social_app_ratio']:.1%}")
print(f"Night Usage: {profile['night_usage_ratio']:.1%}")
print(f"Daily Distance: {profile['daily_distance_km']:.2f} km")
```

### Küme İstatistikleri

```python
clusters_info = profiler.get_cluster_profiles()
for cluster, info in clusters_info.items():
    print(f"{cluster}: {info['size']} kullanıcı")
    print(f"  Avg Home Ratio: {info['home_ratio_mean']:.2f}")
```

## Geliştirilecek Alanlar

1. **Feature Engineering**
   - Daha fazla zaman özellikleri (saat başına aktivite)
   - Uygulama kombinasyonları (co-usage patterns)
   - Mekan ziyaret sıklığı

2. **Clustering**
   - Farklı algoritmaları test et (K-Means, Hierarchical)
   - Silhouette score ile optimize et
   - Dinamik eps hesaplama

3. **Recommender**
   - Daha fazla event türü ekle
   - Content-based ve collaborative filtering
   - A/B testing ve feedback loop

4. **Visualization**
   - UMAP/t-SNE ile görselleştirme
   - Interactive dashboard (Plotly)
   - Tekil kullanıcı profil grafikleri

## Hata Giderme

### "CSV dosyası bulunamadı"
- Dosyaların doğru dizinde olduğundan emin ol
- `out/` klasörü var söyleniyor kontrolet

### "DBSCAN çok fazla gürültü üretiyor"
- eps değerini artır (0.8 → 1.0)
- min_samples değerini azalt (3 → 2)

### "Event önerileri çok tekrarlı"
- Daha fazla event türü ekle `event_recommender.py`'de
- Karakteristik aralıklarını ayarla

## Notlar

- Sistem sahte veriler üzerinde test edilmiş
- Gerçek verilere uyarlamak için kategori eşleşmelerini ayarla
- Event önerileri iş lojiğiyle uyumlu hale getir

## İletişim & Destek

Sorularınız için main_pipeline.py dosyasında debug mode açabilirsin.

