-- Curated seed: Istanbul (28 events) + Kocaeli (14 events) = 42 events
-- starts_at values use now() + interval — seed data always stays valid
-- is_recurring = true events have starts_at/ends_at intentionally null

insert into public.events
  (source, title, description, category, subcategory,
   venue_name, address, city, lat, lng,
   starts_at, ends_at, is_recurring, is_ticketed,
   price_min, price_max, currency, tags, popularity_score)
values

-- ═══════════════════════════════════════════════
--  ISTANBUL — MUSIC
-- ═══════════════════════════════════════════════
('curated',
 'Jazz Night — Nardis Jazz Club',
 'International jazz artists performing. Every Thursday evening.',
 'music', 'jazz',
 'Nardis Jazz Club', 'Kuledibi Sok. No:14, Beyoğlu', 'İstanbul',
 41.0282, 28.9740,
 now() + interval '3 days', now() + interval '3 days' + interval '3 hours',
 true, true, 250, 400, 'TRY',
 array['jazz', 'live music', 'Beyoğlu'], 0.82),

('curated',
 'Rock Concert — Küçükçiftlik Park',
 'Open-air concert by Turkish rock bands.',
 'music', 'rock',
 'Küçükçiftlik Park', 'Darülbedai Cad., Şişli', 'İstanbul',
 41.0617, 28.9994,
 now() + interval '8 days', now() + interval '8 days' + interval '4 hours',
 false, true, 350, 550, 'TRY',
 array['rock', 'open air', 'concert'], 0.76),

('curated',
 'Classical Music Concert — Lütfi Kırdar',
 'Istanbul State Symphony Orchestra gala concert.',
 'music', 'classical',
 'Lütfi Kırdar Kongre Merkezi', 'Harbiye, Şişli', 'İstanbul',
 41.0495, 28.9945,
 now() + interval '5 days', now() + interval '5 days' + interval '2 hours 30 minutes',
 false, true, 150, 600, 'TRY',
 array['classical music', 'symphony', 'Harbiye'], 0.71),

('curated',
 'Babylon Live Performance',
 'Alternative and world music artists.',
 'music', 'alternative',
 'Babylon', 'Şehbender Sok. No:3, Asmalımescit', 'İstanbul',
 41.0313, 28.9767,
 now() + interval '2 days', now() + interval '2 days' + interval '3 hours',
 true, true, 200, 350, 'TRY',
 array['live music', 'Beyoğlu', 'nightlife'], 0.79),

('curated',
 'Acoustic Night — Kadıköy Sahne',
 'Underground and indie music artists in acoustic set.',
 'music', 'acoustic',
 'Kadıköy Sahne', 'Moda Cad., Kadıköy', 'İstanbul',
 40.9853, 29.0234,
 now() + interval '4 days', now() + interval '4 days' + interval '3 hours',
 true, true, 100, 200, 'TRY',
 array['acoustic', 'indie', 'Kadıköy'], 0.68),

-- ═══════════════════════════════════════════════
--  ISTANBUL — CULTURE & ARTS
-- ═══════════════════════════════════════════════
('curated',
 'Pera Museum — Permanent Collection',
 'Anatolian Weights and Measures, Kütahya Tiles and Ceramics, Orientalist Painting collections.',
 'culture', 'museum',
 'Pera Müzesi', 'Meşrutiyet Cad. No:65, Tepebaşı', 'İstanbul',
 41.0329, 28.9751,
 null, null,
 true, true, 75, 150, 'TRY',
 array['museum', 'art', 'Beyoğlu'], 0.88),

('curated',
 'Istanbul Modern — Contemporary Art Exhibition',
 'Turkish and international contemporary artworks. New building at Galataport.',
 'culture', 'museum',
 'İstanbul Modern', 'Meclis-i Mebusan Cad., Karaköy', 'İstanbul',
 41.0236, 28.9813,
 null, null,
 true, true, 100, 200, 'TRY',
 array['contemporary art', 'museum', 'Karaköy'], 0.91),

('curated',
 'SALT Galata — Architecture Exhibition',
 'Comprehensive archive and exhibition on Turkish architectural history.',
 'culture', 'exhibition',
 'SALT Galata', 'Bankalar Cad. No:11, Karaköy', 'İstanbul',
 41.0254, 28.9792,
 null, null,
 true, false, 0, 0, 'TRY',
 array['architecture', 'exhibition', 'free', 'Karaköy'], 0.74),

('curated',
 'Sakıp Sabancı Museum — Calligraphy Exhibition',
 'Ottoman calligraphy works and the Sakıp Sabancı collection.',
 'culture', 'museum',
 'Sakıp Sabancı Müzesi', 'Sakıp Sabancı Cad. No:42, Emirgan', 'İstanbul',
 41.0857, 29.0534,
 null, null,
 true, true, 100, 200, 'TRY',
 array['museum', 'calligraphy', 'Emirgan', 'Bosphorus'], 0.85),

('curated',
 'Kadıköy Theatre Festival',
 'Short plays festival by independent theatre groups.',
 'culture', 'theatre',
 'Kadıköy Kültür Merkezi', 'Söğütlüçeşme Cad., Kadıköy', 'İstanbul',
 40.9910, 29.0246,
 now() + interval '10 days', now() + interval '12 days',
 false, true, 50, 150, 'TRY',
 array['theatre', 'festival', 'Kadıköy'], 0.65),

-- ═══════════════════════════════════════════════
--  ISTANBUL — OUTDOORS & NATURE
-- ═══════════════════════════════════════════════
('curated',
 'Maçka Park Morning Yoga',
 'Outdoor yoga in the park every day at 07:30. All levels welcome.',
 'outdoor', 'yoga',
 'Maçka Demokrasi Parkı', 'Maçka, Beşiktaş', 'İstanbul',
 41.0444, 29.0002,
 null, null,
 true, false, 0, 0, 'TRY',
 array['yoga', 'morning', 'park', 'free'], 0.72),

('curated',
 'Emirgan Grove Nature Walk',
 'Guided nature walk on forest paths with Bosphorus views. Weekends.',
 'outdoor', 'nature walk',
 'Emirgan Korusu', 'Emirgan, Sarıyer', 'İstanbul',
 41.0944, 29.0559,
 null, null,
 true, false, 0, 0, 'TRY',
 array['hiking', 'nature', 'Bosphorus', 'free'], 0.78),

('curated',
 'Belgrade Forest Cycling Tour',
 'Forest cycling routes. Bike rental available.',
 'outdoor', 'cycling',
 'Belgrad Ormanı Giriş', 'Bahçeköy, Sarıyer', 'İstanbul',
 41.1611, 28.9713,
 null, null,
 true, false, 0, 50, 'TRY',
 array['cycling', 'forest', 'nature'], 0.81),

('curated',
 'Bosphorus Sunset Boat Tour',
 '2-hour sunset tour passing under the Bosphorus Bridge.',
 'outdoor', 'boat',
 'Beşiktaş İskelesi', 'Beşiktaş Meydanı', 'İstanbul',
 41.0439, 29.0056,
 now() + interval '1 days', now() + interval '1 days' + interval '2 hours',
 true, true, 200, 350, 'TRY',
 array['boat', 'Bosphorus', 'sunset'], 0.89),

('curated',
 'Princes Islands Cycling & Picnic',
 'No cars on Büyükada — explore the island by bike and enjoy a seaside picnic.',
 'outdoor', 'cycling',
 'Büyükada Vapur İskelesi', 'Büyükada, Adalar', 'İstanbul',
 40.8738, 29.1199,
 null, null,
 true, false, 0, 80, 'TRY',
 array['island', 'cycling', 'picnic', 'sea'], 0.86),

-- ═══════════════════════════════════════════════
--  ISTANBUL — FOOD & DRINK
-- ═══════════════════════════════════════════════
('curated',
 'Kadıköy Food Tour',
 'Guided street food tour through the historic market. 10 stops.',
 'food', 'food tour',
 'Kadıköy Çarşısı', 'Mühürdar Cad., Kadıköy', 'İstanbul',
 40.9905, 29.0256,
 null, null,
 true, true, 300, 300, 'TRY',
 array['food', 'tour', 'Kadıköy', 'street food'], 0.83),

('curated',
 'Istanbul Gourmet Festival',
 'The city''s best restaurants and chefs gathered in one place. 3 days.',
 'food', 'festival',
 'Harbiye Cemil Topuzlu Parkı', 'Harbiye, Şişli', 'İstanbul',
 41.0479, 28.9905,
 now() + interval '14 days', now() + interval '16 days',
 false, false, 0, 0, 'TRY',
 array['festival', 'gourmet', 'food', 'open air'], 0.77),

('curated',
 'Karaköy Coffee Festival',
 'Turkey''s specialty coffee producers and baristas.',
 'food', 'festival',
 'SALT Galata Avlusu', 'Bankalar Cad., Karaköy', 'İstanbul',
 41.0252, 28.9789,
 now() + interval '6 days', now() + interval '7 days',
 false, false, 0, 0, 'TRY',
 array['coffee', 'specialty', 'festival', 'Karaköy'], 0.74),

-- ═══════════════════════════════════════════════
--  ISTANBUL — SPORTS
-- ═══════════════════════════════════════════════
('curated',
 'Istanbul Marathon Training Run',
 '10km group run at Fenerbahçe Park every Sunday.',
 'sports', 'running',
 'Fenerbahçe Parkı', 'Bağdat Cad., Kadıköy', 'İstanbul',
 40.9716, 29.0400,
 null, null,
 true, false, 0, 0, 'TRY',
 array['running', 'marathon', 'group', 'free'], 0.69),

('curated',
 'Beach Volleyball — Florya',
 'Beach volleyball every weekend. Open participation.',
 'sports', 'volleyball',
 'Florya Sahili', 'Florya, Bakırköy', 'İstanbul',
 40.9793, 28.7731,
 null, null,
 true, false, 0, 0, 'TRY',
 array['volleyball', 'beach', 'sports', 'open air'], 0.64),

-- ═══════════════════════════════════════════════
--  ISTANBUL — WORKSHOPS & EDUCATION
-- ═══════════════════════════════════════════════
('curated',
 'Ceramics Workshop — Cihangir',
 'Beginner-level pottery throwing and painting. 3-hour session.',
 'workshop', 'ceramics',
 'Cihangir Sanat Atölyesi', 'Akarsu Cad., Cihangir', 'İstanbul',
 41.0340, 28.9808,
 now() + interval '5 days', now() + interval '5 days' + interval '3 hours',
 true, true, 400, 600, 'TRY',
 array['ceramics', 'workshop', 'crafts', 'Cihangir'], 0.71),

('curated',
 'Digital Photography Workshop',
 'Composition and lighting techniques. DSLR or mirrorless required.',
 'workshop', 'photography',
 'Moda Sahil', 'Moda Cad., Kadıköy', 'İstanbul',
 40.9849, 29.0291,
 now() + interval '9 days', now() + interval '9 days' + interval '4 hours',
 false, true, 350, 500, 'TRY',
 array['photography', 'workshop', 'art'], 0.67),

('curated',
 'Turkish Cuisine Cooking Workshop',
 'Traditional Turkish cooking workshop. Ingredients included.',
 'workshop', 'cooking',
 'Cooking Alaturka', 'Akbıyık Cad., Sultanahmet', 'İstanbul',
 41.0047, 28.9760,
 now() + interval '7 days', now() + interval '7 days' + interval '3 hours',
 true, true, 500, 700, 'TRY',
 array['cooking', 'Turkish cuisine', 'workshop'], 0.75),

-- ═══════════════════════════════════════════════
--  ISTANBUL — FAMILY
-- ═══════════════════════════════════════════════
('curated',
 'Children''s Theatre — Fairy Tale Land',
 'Interactive fairy tale play for children aged 4-10.',
 'family', 'theatre',
 'Şişli Kültür Merkezi', 'Halaskargazi Cad., Şişli', 'İstanbul',
 41.0570, 28.9880,
 now() + interval '6 days', now() + interval '6 days' + interval '1 hours 30 minutes',
 true, true, 100, 180, 'TRY',
 array['children', 'theatre', 'family', 'fairy tale'], 0.73),

('curated',
 'Science Centre Weekend Activity',
 'Interactive science experiments and workshops. Ages 6-14.',
 'family', 'education',
 'Koç Müzesi Bilim Merkezi', 'Hasköy Cad., Hasköy', 'İstanbul',
 41.0453, 28.9597,
 null, null,
 true, true, 80, 150, 'TRY',
 array['science', 'children', 'education', 'museum'], 0.80),

('curated',
 'Emirgan Park Picnic Day',
 'Large lawn and children''s playground on the Bosphorus for family picnics.',
 'family', 'picnic',
 'Emirgan Parkı', 'Emirgan, Sarıyer', 'İstanbul',
 41.0918, 29.0549,
 null, null,
 true, false, 0, 0, 'TRY',
 array['picnic', 'park', 'family', 'Bosphorus', 'free'], 0.84),

-- ═══════════════════════════════════════════════
--  ISTANBUL — CULTURE (extra)
-- ═══════════════════════════════════════════════
('curated',
 'Topkapi Palace Guided Tour',
 'Ottoman palace complex including the treasury and harem sections.',
 'culture', 'historic tour',
 'Topkapı Sarayı', 'Sultanahmet, Fatih', 'İstanbul',
 41.0115, 28.9833,
 null, null,
 true, true, 150, 400, 'TRY',
 array['historic', 'museum', 'Ottoman', 'Sultanahmet'], 0.93),

('curated',
 'Street Art Tour — Karaköy & Tophane',
 'Discover the graffiti and street art of Karaköy.',
 'culture', 'tour',
 'Karaköy Meydanı', 'Karaköy, Beyoğlu', 'İstanbul',
 41.0232, 28.9748,
 null, null,
 true, true, 150, 200, 'TRY',
 array['street art', 'tour', 'Karaköy', 'art'], 0.66),

-- ═══════════════════════════════════════════════
--  KOCAELI — MUSIC
-- ═══════════════════════════════════════════════
('curated',
 'Jazz Night — Kocaeli Cultural Centre',
 'Live jazz performances at the city cultural centre. Every Friday evening.',
 'music', 'jazz',
 'Kocaeli Kültür Merkezi', 'İzmit Meydan, İzmit', 'Kocaeli',
 40.7654, 29.9408,
 now() + interval '4 days', now() + interval '4 days' + interval '3 hours',
 true, true, 100, 200, 'TRY',
 array['jazz', 'live music', 'İzmit'], 0.71),

('curated',
 'Gulf Open-Air Concert — Körfez',
 'Free open-air concert series on the İzmit Bay waterfront.',
 'music', 'pop',
 'Körfez Sahil Parkı', 'Körfez, Kocaeli', 'Kocaeli',
 40.7731, 29.7892,
 now() + interval '6 days', now() + interval '6 days' + interval '2 hours 30 minutes',
 true, false, 0, 0, 'TRY',
 array['open air', 'concert', 'free', 'waterfront'], 0.74),

-- ═══════════════════════════════════════════════
--  KOCAELI — CULTURE & ARTS
-- ═══════════════════════════════════════════════
('curated',
 'Kocaeli Museum — Archaeology & Ethnography',
 'Regional archaeological finds and Ottoman-era ethnographic collection.',
 'culture', 'museum',
 'Kocaeli Müzesi', 'Hürriyet Cad. No:1, İzmit', 'Kocaeli',
 40.7649, 29.9377,
 null, null,
 true, true, 40, 80, 'TRY',
 array['archaeology', 'museum', 'history'], 0.78),

('curated',
 'Seka Park — Industrial Heritage Museum',
 'Former SEKA paper factory transformed into an open-air museum and park. Free entry.',
 'culture', 'museum',
 'Seka Kağıt Müzesi', 'Yenişehir Mah., İzmit', 'Kocaeli',
 40.7665, 29.9372,
 null, null,
 true, false, 0, 0, 'TRY',
 array['industrial heritage', 'museum', 'free', 'park'], 0.82),

('curated',
 'Kocaeli City Museum — Urban History',
 'The story of Kocaeli from ancient Nicomedia to the modern city.',
 'culture', 'museum',
 'Kocaeli Şehir Müzesi', 'İzmit Meydan, İzmit', 'Kocaeli',
 40.7651, 29.9398,
 null, null,
 true, true, 30, 60, 'TRY',
 array['city history', 'museum', 'İzmit'], 0.69),

-- ═══════════════════════════════════════════════
--  KOCAELI — OUTDOORS & NATURE
-- ═══════════════════════════════════════════════
('curated',
 'Sapanca Lake Nature Walk',
 'Scenic trail around one of Turkey''s cleanest freshwater lakes. Stunning forest views.',
 'outdoor', 'nature walk',
 'Sapanca Gölü', 'Sapanca, Kocaeli', 'Kocaeli',
 40.6903, 30.2671,
 null, null,
 true, false, 0, 0, 'TRY',
 array['lake', 'nature', 'hiking', 'free'], 0.91),

('curated',
 'Kartepe Mountain Hiking Trail',
 'Forested trails on Kartepe with panoramic views of İzmit Bay. All fitness levels.',
 'outdoor', 'hiking',
 'Kartepe Dağı', 'Kartepe, Kocaeli', 'Kocaeli',
 40.7193, 29.9100,
 null, null,
 true, false, 0, 0, 'TRY',
 array['hiking', 'mountain', 'nature', 'free'], 0.87),

('curated',
 'İzmit Bay Sunset Boat Tour',
 '90-minute sunset cruise across the Gulf of İzmit. Departs from İzmit pier.',
 'outdoor', 'boat',
 'İzmit İskelesi', 'Yalılar Mah., İzmit', 'Kocaeli',
 40.7645, 29.9350,
 now() + interval '2 days', now() + interval '2 days' + interval '1 hours 30 minutes',
 true, true, 150, 250, 'TRY',
 array['boat', 'gulf', 'sunset'], 0.83),

-- ═══════════════════════════════════════════════
--  KOCAELI — FOOD & DRINK
-- ═══════════════════════════════════════════════
('curated',
 'Pişmaniye Festival — İzmit',
 'Kocaeli''s iconic cotton candy dessert festival. Tastings, workshops and street food.',
 'food', 'festival',
 'İzmit Meydan', 'Cumhuriyet Cad., İzmit', 'Kocaeli',
 40.7654, 29.9408,
 now() + interval '10 days', now() + interval '12 days',
 false, false, 0, 0, 'TRY',
 array['festival', 'local food', 'street food', 'free'], 0.79),

('curated',
 'İzmit Food Tour — Gulf Flavours',
 'Guided tasting tour of İzmit''s best local spots. Pişmaniye, balık ekmek and more.',
 'food', 'food tour',
 'İzmit Çarşısı', 'Hürriyet Cad., İzmit', 'Kocaeli',
 40.7648, 29.9415,
 null, null,
 true, true, 250, 250, 'TRY',
 array['food tour', 'local cuisine', 'İzmit'], 0.75),

-- ═══════════════════════════════════════════════
--  KOCAELI — SPORTS
-- ═══════════════════════════════════════════════
('curated',
 'Sabancı Park Morning Run',
 'Weekly group run through Sabancı Cultural Park along the seafront. Every Sunday 08:00.',
 'sports', 'running',
 'Sabancı Kültür Parkı', 'İzmit Sahili, İzmit', 'Kocaeli',
 40.7660, 29.9330,
 null, null,
 true, false, 0, 0, 'TRY',
 array['running', 'park', 'morning', 'free'], 0.72),

-- ═══════════════════════════════════════════════
--  KOCAELI — WORKSHOPS
-- ═══════════════════════════════════════════════
('curated',
 'Traditional Tile Art Workshop — İzmit',
 'Beginner course in Iznik-style tile painting. Materials included. 3-hour session.',
 'workshop', 'tile art',
 'İzmit Sanat Atölyesi', 'Yenişehir Mah., İzmit', 'Kocaeli',
 40.7670, 29.9390,
 now() + interval '7 days', now() + interval '7 days' + interval '3 hours',
 true, true, 300, 450, 'TRY',
 array['tile art', 'workshop', 'crafts'], 0.67),

-- ═══════════════════════════════════════════════
--  KOCAELI — FAMILY
-- ═══════════════════════════════════════════════
('curated',
 'Kocaeli Zoo & Animal Park',
 'Large animal park with over 100 species. Picnic areas and children''s playground.',
 'family', 'zoo',
 'Kocaeli Hayvan Parkı', 'Başiskele, Kocaeli', 'Kocaeli',
 40.7580, 29.9530,
 null, null,
 true, true, 50, 100, 'TRY',
 array['zoo', 'children', 'family', 'animals'], 0.85),

('curated',
 'Kartepe Family Picnic & Sledging',
 'Family day out on Kartepe mountain. Picnic spots, nature trails and seasonal sledging.',
 'family', 'picnic',
 'Kartepe Dağı Piknik Alanı', 'Kartepe, Kocaeli', 'Kocaeli',
 40.7210, 29.9115,
 null, null,
 true, false, 0, 30, 'TRY',
 array['picnic', 'mountain', 'family', 'nature'], 0.80);
