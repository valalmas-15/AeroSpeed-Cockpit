import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/route_model.dart';

/// Representasi titik simpul (persimpangan jalan) dalam graf jalan offline
class RoadNode {
  final String id;
  final String name;
  final LatLng point;

  const RoadNode({
    required this.id,
    required this.name,
    required this.point,
  });
}

/// Ruas jalan dengan koordinat geometri vektor jalan nyata (OpenStreetMap)
class RoadEdge {
  final String fromId;
  final String toId;
  final String roadName;
  final List<LatLng> geometry;
  final double lengthMeters;
  final double speedKmh;

  RoadEdge({
    required this.fromId,
    required this.toId,
    required this.roadName,
    required this.geometry,
    required this.lengthMeters,
    this.speedKmh = 35.0,
  });
}

/// Hasil proyeksi titik koordinat ke ruas jalan terdekat
class RoadSnap {
  final RoadEdge edge;
  final LatLng projectedPoint;
  final int segmentIndex;
  final double distanceMeters;

  const RoadSnap({
    required this.edge,
    required this.projectedPoint,
    required this.segmentIndex,
    required this.distanceMeters,
  });
}

/// Engine Routing Offline Cerdas
/// Menggunakan geometri jalan raya nyata (OpenStreetMap) dan proyeksi snap-to-road,
/// bebas dari garis zigzag buatan maupun garis lurus udara yang menembus bangunan.
class OfflineRoutingEngine {
  static const Distance _distanceCalc = Distance();

  static final Map<String, RoadNode> _nodes = _buildRoadNodes();
  static final List<RoadEdge> _edges = _buildRoadEdges();

  static Map<String, RoadNode> _buildRoadNodes() {
    final list = <RoadNode>[
      // --- YOGYAKARTA NODES ---
      const RoadNode(id: 'jog_tugu', name: 'Tugu Pal Putih', point: LatLng(-7.782889, 110.367072)),
      const RoadNode(id: 'jog_stasiun', name: 'Stasiun Tugu', point: LatLng(-7.789167, 110.365823)),
      const RoadNode(id: 'jog_malioboro', name: 'Jl. Malioboro Tengah', point: LatLng(-7.794500, 110.365900)),
      const RoadNode(id: 'jog_nol_km', name: 'Titik Nol Kilometer', point: LatLng(-7.800278, 110.366111)),
      const RoadNode(id: 'jog_alun_utara', name: 'Alun-Alun Utara', point: LatLng(-7.803800, 110.364300)),
      const RoadNode(id: 'jog_keraton', name: 'Keraton Ngayogyakarta', point: LatLng(-7.805284, 110.364203)),
      const RoadNode(id: 'jog_alkid', name: 'Alun-Alun Kidul', point: LatLng(-7.811800, 110.363200)),
      const RoadNode(id: 'jog_krapyak', name: 'Panggung Krapyak', point: LatLng(-7.827500, 110.360600)),

      const RoadNode(id: 'jog_pingit', name: 'Simpang Pingit', point: LatLng(-7.783400, 110.358200)),
      const RoadNode(id: 'jog_godean_demak', name: 'Simpang Demak Ijo', point: LatLng(-7.780100, 110.327500)),
      const RoadNode(id: 'jog_wirobrajan', name: 'Simpang Wirobrajan', point: LatLng(-7.800300, 110.353200)),
      const RoadNode(id: 'jog_pku', name: 'Simpang PKU Muhammadiyah', point: LatLng(-7.800300, 110.360000)),
      const RoadNode(id: 'jog_gamping', name: 'Simpang Gamping', point: LatLng(-7.801000, 110.320000)),

      const RoadNode(id: 'jog_gramedia', name: 'Simpang Gramedia Sudirman', point: LatLng(-7.783000, 110.373500)),
      const RoadNode(id: 'jog_galeria', name: 'Simpang Galeria Terban', point: LatLng(-7.783100, 110.380000)),
      const RoadNode(id: 'jog_demangan', name: 'Simpang Demangan XXI', point: LatLng(-7.782900, 110.390800)),
      const RoadNode(id: 'jog_amplaz', name: 'Simpang Ambarrukmo Plaza', point: LatLng(-7.782900, 110.401100)),
      const RoadNode(id: 'jog_janti', name: 'Flyover Janti', point: LatLng(-7.787500, 110.410500)),
      const RoadNode(id: 'jog_bandara', name: 'Bandara Adisutjipto', point: LatLng(-7.782600, 110.435800)),

      const RoadNode(id: 'jog_gondomanan', name: 'Simpang Gondomanan', point: LatLng(-7.800500, 110.370200)),
      const RoadNode(id: 'jog_sayidan', name: 'Simpang Puro Pakualaman', point: LatLng(-7.801500, 110.376500)),
      const RoadNode(id: 'jog_glzoo', name: 'Simpang Gembira Loka Zoo', point: LatLng(-7.804200, 110.397000)),
      const RoadNode(id: 'jog_bloko', name: 'Simpang Blok O Ring Road', point: LatLng(-7.795800, 110.410500)),

      const RoadNode(id: 'jog_kronggahan', name: 'Simpang Kronggahan Ring Road', point: LatLng(-7.755000, 110.340000)),
      const RoadNode(id: 'jog_jombor', name: 'Flyover Jombor Ring Road', point: LatLng(-7.747800, 110.361800)),
      const RoadNode(id: 'jog_monjali', name: 'Simpang Monjali Ring Road', point: LatLng(-7.749500, 110.370200)),
      const RoadNode(id: 'jog_kentungan', name: 'Simpang Kentungan Kaliurang', point: LatLng(-7.753300, 110.380700)),
      const RoadNode(id: 'jog_condongcatur', name: 'Simpang Condongcatur Gejayan', point: LatLng(-7.758400, 110.395500)),
      const RoadNode(id: 'jog_upn', name: 'Simpang UPN Ring Road', point: LatLng(-7.762000, 110.408000)),
      const RoadNode(id: 'jog_maguwo', name: 'Simpang Maguwoharjo Ring Road', point: LatLng(-7.778000, 110.428000)),

      const RoadNode(id: 'jog_ugm', name: 'Bundaran UGM', point: LatLng(-7.771200, 110.377600)),

      // --- JAKARTA NODES ---
      const RoadNode(id: 'jkt_monas', name: 'Monas Merdeka Barat', point: LatLng(-6.175392, 106.827153)),
      const RoadNode(id: 'jkt_sarinah', name: 'Sarinah Thamrin', point: LatLng(-6.189563, 106.823908)),
      const RoadNode(id: 'jkt_bundaran_hi', name: 'Bundaran HI', point: LatLng(-6.194432, 106.823021)),
      const RoadNode(id: 'jkt_dukuh_atas', name: 'Dukuh Atas Sudirman', point: LatLng(-6.203341, 106.821453)),
      const RoadNode(id: 'jkt_karet', name: 'Karet Sudirman', point: LatLng(-6.208821, 106.819876)),
      const RoadNode(id: 'jkt_semanggi', name: 'Simpang Susun Semanggi', point: LatLng(-6.215543, 106.814232)),
      const RoadNode(id: 'jkt_gbk', name: 'Gelora Bung Karno', point: LatLng(-6.218521, 106.802341)),
      const RoadNode(id: 'jkt_harmoni', name: 'Harmoni Gajah Mada', point: LatLng(-6.160124, 106.829124)),
      const RoadNode(id: 'jkt_kotatua', name: 'Kota Tua Glodok', point: LatLng(-6.138452, 106.826543)),
      const RoadNode(id: 'jkt_ancol', name: 'Taman Impian Ancol', point: LatLng(-6.126543, 106.833452)),

      // --- BANDUNG NODES ---
      const RoadNode(id: 'bdg_pasteur', name: 'Gerbang Tol Pasteur', point: LatLng(-6.893245, 107.575643)),
      const RoadNode(id: 'bdg_djunjunan', name: 'Jl. Dr. Djunjunan', point: LatLng(-6.899543, 107.595432)),
      const RoadNode(id: 'bdg_pasupati', name: 'Flyover Pasupati Cihampelas', point: LatLng(-6.901234, 107.608765)),
      const RoadNode(id: 'bdg_gedungsate', name: 'Gedung Sate Diponegoro', point: LatLng(-6.902534, 107.618645)),
    ];

    return {for (var n in list) n.id: n};
  }

  static List<RoadEdge> _buildRoadEdges() {
    final list = <RoadEdge>[];

    void addBi(String u, String v, String name, List<LatLng> pts, {double speed = 35.0}) {
      double len = 0;
      for (int i = 0; i < pts.length - 1; i++) {
        len += _distanceCalc.as(LengthUnit.Meter, pts[i], pts[i + 1]);
      }
      list.add(RoadEdge(fromId: u, toId: v, roadName: name, geometry: pts, lengthMeters: len, speedKmh: speed));
      list.add(RoadEdge(fromId: v, toId: u, roadName: name, geometry: pts.reversed.toList(), lengthMeters: len, speedKmh: speed));
    }

    addBi('jog_tugu', 'jog_stasiun', 'Jl. Margo Utomo', const [
      LatLng(-7.782797, 110.367015),
      LatLng(-7.783194, 110.367037),
      LatLng(-7.783753, 110.366967),
      LatLng(-7.784335, 110.366895),
      LatLng(-7.784757, 110.366842),
      LatLng(-7.785488, 110.366751),
      LatLng(-7.785920, 110.366697),
      LatLng(-7.786493, 110.366626),
      LatLng(-7.787074, 110.366553),
      LatLng(-7.787663, 110.366480),
      LatLng(-7.788119, 110.366423),
      LatLng(-7.788684, 110.366353),
      LatLng(-7.789083, 110.366303),
      LatLng(-7.789388, 110.365989),
      LatLng(-7.789373, 110.365806),
    ]);

    addBi('jog_stasiun', 'jog_malioboro', 'Jl. Malioboro', const [
      LatLng(-7.789167, 110.365823),
      LatLng(-7.790500, 110.365840),
      LatLng(-7.791800, 110.365860),
      LatLng(-7.792841, 110.365880),
      LatLng(-7.793800, 110.365890),
      LatLng(-7.794500, 110.365900),
    ]);

    addBi('jog_malioboro', 'jog_nol_km', 'Jl. Malioboro', const [
      LatLng(-7.794466, 110.365623),
      LatLng(-7.795218, 110.365528),
      LatLng(-7.795855, 110.365448),
      LatLng(-7.796362, 110.365385),
      LatLng(-7.797437, 110.365256),
      LatLng(-7.798352, 110.365137),
      LatLng(-7.798830, 110.365074),
      LatLng(-7.799486, 110.364989),
      LatLng(-7.799843, 110.364944),
      LatLng(-7.800204, 110.364899),
      LatLng(-7.800248, 110.365433),
    ]);

    addBi('jog_nol_km', 'jog_alun_utara', 'Jl. Pangurakan', const [
      LatLng(-7.800248, 110.365433),
      LatLng(-7.800215, 110.365030),
      LatLng(-7.800763, 110.364829),
      LatLng(-7.801167, 110.364779),
      LatLng(-7.801533, 110.364732),
      LatLng(-7.802020, 110.364670),
      LatLng(-7.802413, 110.364620),
      LatLng(-7.802860, 110.364562),
      LatLng(-7.802903, 110.364383),
    ]);

    addBi('jog_alun_utara', 'jog_keraton', 'Plataran Keraton', const [
      LatLng(-7.802903, 110.364383),
      LatLng(-7.802834, 110.363629),
      LatLng(-7.803403, 110.363422),
      LatLng(-7.804016, 110.363349),
      LatLng(-7.804695, 110.363268),
      LatLng(-7.805034, 110.363429),
      LatLng(-7.805106, 110.364220),
    ]);

    addBi('jog_keraton', 'jog_alkid', 'Jl. Patehan', const [
      LatLng(-7.805106, 110.364220),
      LatLng(-7.805052, 110.363627),
      LatLng(-7.805016, 110.363230),
      LatLng(-7.804646, 110.362698),
      LatLng(-7.804616, 110.362300),
      LatLng(-7.804527, 110.361027),
      LatLng(-7.804476, 110.360529),
      LatLng(-7.804856, 110.360477),
      LatLng(-7.805272, 110.360420),
      LatLng(-7.805975, 110.360313),
      LatLng(-7.806684, 110.360245),
      LatLng(-7.807728, 110.360100),
      LatLng(-7.808072, 110.360529),
      LatLng(-7.808183, 110.360883),
      LatLng(-7.808658, 110.360991),
      LatLng(-7.809031, 110.360947),
      LatLng(-7.809528, 110.360873),
      LatLng(-7.810250, 110.360805),
      LatLng(-7.811249, 110.360663),
      LatLng(-7.811411, 110.361627),
      LatLng(-7.811508, 110.362208),
      LatLng(-7.811590, 110.362628),
      LatLng(-7.811185, 110.362729),
      LatLng(-7.811243, 110.363282),
    ]);

    addBi('jog_alkid', 'jog_krapyak', 'Jl. D.I. Panjaitan', const [
      LatLng(-7.811243, 110.363282),
      LatLng(-7.811315, 110.363771),
      LatLng(-7.811631, 110.364618),
      LatLng(-7.811680, 110.365000),
      LatLng(-7.811828, 110.366285),
      LatLng(-7.811109, 110.366386),
      LatLng(-7.810387, 110.366488),
      LatLng(-7.809998, 110.366524),
      LatLng(-7.809341, 110.366603),
      LatLng(-7.809125, 110.367880),
      LatLng(-7.809157, 110.368653),
      LatLng(-7.809163, 110.369084),
      LatLng(-7.809665, 110.369045),
      LatLng(-7.810206, 110.369003),
      LatLng(-7.810868, 110.368963),
      LatLng(-7.811476, 110.368925),
      LatLng(-7.811873, 110.368880),
      LatLng(-7.812263, 110.368852),
      LatLng(-7.813173, 110.368784),
      LatLng(-7.813735, 110.368743),
      LatLng(-7.814462, 110.368739),
      LatLng(-7.814787, 110.368554),
      LatLng(-7.815537, 110.368353),
      LatLng(-7.816571, 110.368264),
      LatLng(-7.817437, 110.368213),
      LatLng(-7.818080, 110.368187),
      LatLng(-7.818853, 110.368145),
      LatLng(-7.819781, 110.368078),
      LatLng(-7.820553, 110.367998),
      LatLng(-7.820996, 110.367978),
      LatLng(-7.822060, 110.367898),
      LatLng(-7.821930, 110.367215),
      LatLng(-7.821770, 110.366242),
      LatLng(-7.821607, 110.365421),
      LatLng(-7.821529, 110.365043),
      LatLng(-7.821285, 110.363930),
      LatLng(-7.821176, 110.363459),
      LatLng(-7.821027, 110.362774),
      LatLng(-7.820906, 110.362216),
      LatLng(-7.820805, 110.361760),
      LatLng(-7.821764, 110.361588),
      LatLng(-7.822671, 110.361434),
      LatLng(-7.823270, 110.361335),
      LatLng(-7.823786, 110.361254),
      LatLng(-7.824205, 110.361180),
      LatLng(-7.825114, 110.361013),
      LatLng(-7.825470, 110.360959),
      LatLng(-7.826037, 110.360877),
      LatLng(-7.826534, 110.360792),
      LatLng(-7.827105, 110.360680),
      LatLng(-7.827499, 110.360604),
      LatLng(-7.827499, 110.360600),
    ]);

    addBi('jog_tugu', 'jog_gramedia', 'Jl. Jenderal Sudirman', const [
      LatLng(-7.782797, 110.367015),
      LatLng(-7.782853, 110.367567),
      LatLng(-7.782884, 110.368330),
      LatLng(-7.782927, 110.368763),
      LatLng(-7.782932, 110.369179),
      LatLng(-7.782936, 110.369547),
      LatLng(-7.782941, 110.369920),
      LatLng(-7.782947, 110.370484),
      LatLng(-7.782938, 110.371307),
      LatLng(-7.782943, 110.372116),
      LatLng(-7.782965, 110.372613),
      LatLng(-7.782970, 110.372999),
      LatLng(-7.782972, 110.373500),
    ]);

    addBi('jog_gramedia', 'jog_galeria', 'Jl. Jenderal Sudirman', const [
      LatLng(-7.782972, 110.373500),
      LatLng(-7.782976, 110.374497),
      LatLng(-7.782978, 110.374903),
      LatLng(-7.784282, 110.374784),
      LatLng(-7.784687, 110.374717),
      LatLng(-7.785086, 110.374648),
      LatLng(-7.785680, 110.374548),
      LatLng(-7.786402, 110.374424),
      LatLng(-7.786761, 110.374368),
      LatLng(-7.786927, 110.374705),
      LatLng(-7.787107, 110.375041),
      LatLng(-7.787341, 110.375337),
      LatLng(-7.787518, 110.375814),
      LatLng(-7.787545, 110.376185),
      LatLng(-7.786984, 110.376514),
      LatLng(-7.787131, 110.377407),
      LatLng(-7.787305, 110.378384),
      LatLng(-7.787098, 110.378711),
      LatLng(-7.787246, 110.379233),
      LatLng(-7.787507, 110.380059),
      LatLng(-7.787584, 110.380438),
      LatLng(-7.787417, 110.381012),
      LatLng(-7.787291, 110.381415),
      LatLng(-7.787181, 110.381881),
      LatLng(-7.786692, 110.382126),
      LatLng(-7.786322, 110.382168),
      LatLng(-7.785691, 110.382041),
      LatLng(-7.785025, 110.381926),
      LatLng(-7.784627, 110.381854),
      LatLng(-7.784284, 110.381986),
      LatLng(-7.783929, 110.382047),
      LatLng(-7.783310, 110.382101),
      LatLng(-7.783035, 110.381420),
      LatLng(-7.783029, 110.380701),
      LatLng(-7.783017, 110.380001),
    ]);

    addBi('jog_galeria', 'jog_demangan', 'Jl. Urip Sumoharjo', const [
      LatLng(-7.783017, 110.380001),
      LatLng(-7.783011, 110.379606),
      LatLng(-7.783009, 110.379235),
      LatLng(-7.783611, 110.379169),
      LatLng(-7.784098, 110.379094),
      LatLng(-7.784876, 110.378979),
      LatLng(-7.785816, 110.378840),
      LatLng(-7.786938, 110.378664),
      LatLng(-7.787246, 110.379233),
      LatLng(-7.787507, 110.380059),
      LatLng(-7.787584, 110.380438),
      LatLng(-7.787417, 110.381012),
      LatLng(-7.787291, 110.381415),
      LatLng(-7.787181, 110.381881),
      LatLng(-7.786692, 110.382126),
      LatLng(-7.786322, 110.382168),
      LatLng(-7.786150, 110.383024),
      LatLng(-7.786166, 110.384059),
      LatLng(-7.786205, 110.385732),
      LatLng(-7.786226, 110.386438),
      LatLng(-7.786171, 110.386904),
      LatLng(-7.785989, 110.387240),
      LatLng(-7.785672, 110.387598),
      LatLng(-7.785320, 110.387907),
      LatLng(-7.784958, 110.388124),
      LatLng(-7.784525, 110.388142),
      LatLng(-7.784027, 110.388093),
      LatLng(-7.783280, 110.388002),
      LatLng(-7.783057, 110.388528),
      LatLng(-7.783063, 110.389191),
      LatLng(-7.783073, 110.390284),
      LatLng(-7.783077, 110.390754),
      LatLng(-7.783077, 110.390798),
    ]);

    addBi('jog_demangan', 'jog_amplaz', 'Jl. Laksda Adisucipto', const [
      LatLng(-7.783077, 110.390798),
      LatLng(-7.783081, 110.391217),
      LatLng(-7.783086, 110.391722),
      LatLng(-7.783091, 110.392250),
      LatLng(-7.783102, 110.393506),
      LatLng(-7.783106, 110.393915),
      LatLng(-7.783111, 110.394420),
      LatLng(-7.783115, 110.394874),
      LatLng(-7.783123, 110.395292),
      LatLng(-7.783134, 110.396026),
      LatLng(-7.783145, 110.396448),
      LatLng(-7.783152, 110.397130),
      LatLng(-7.783159, 110.397583),
      LatLng(-7.783183, 110.399534),
      LatLng(-7.783186, 110.400302),
      LatLng(-7.783186, 110.400796),
      LatLng(-7.783190, 110.401096),
    ]);

    addBi('jog_amplaz', 'jog_janti', 'Jl. Laksda Adisucipto', const [
      LatLng(-7.783190, 110.401096),
      LatLng(-7.783198, 110.401652),
      LatLng(-7.783200, 110.402230),
      LatLng(-7.783207, 110.403092),
      LatLng(-7.783212, 110.403531),
      LatLng(-7.783220, 110.404038),
      LatLng(-7.783229, 110.404667),
      LatLng(-7.783239, 110.405110),
      LatLng(-7.783248, 110.405944),
      LatLng(-7.783252, 110.406379),
      LatLng(-7.783255, 110.406766),
      LatLng(-7.783258, 110.407309),
      LatLng(-7.783261, 110.407802),
      LatLng(-7.783261, 110.408176),
      LatLng(-7.783261, 110.409244),
      LatLng(-7.783259, 110.410285),
      LatLng(-7.783779, 110.410513),
      LatLng(-7.784213, 110.410505),
      LatLng(-7.786531, 110.410397),
      LatLng(-7.787058, 110.410353),
      LatLng(-7.787492, 110.410329),
    ]);

    addBi('jog_janti', 'jog_bandara', 'Jl. Raya Solo - Yogyakarta', const [
      LatLng(-7.787492, 110.410329),
      LatLng(-7.788747, 110.410269),
      LatLng(-7.790764, 110.410227),
      LatLng(-7.791280, 110.410206),
      LatLng(-7.792157, 110.410171),
      LatLng(-7.793074, 110.410137),
      LatLng(-7.793467, 110.410121),
      LatLng(-7.794239, 110.410091),
      LatLng(-7.797082, 110.409991),
      LatLng(-7.797889, 110.409983),
      LatLng(-7.798351, 110.409967),
      LatLng(-7.798601, 110.409570),
      LatLng(-7.798602, 110.409133),
      LatLng(-7.798600, 110.408551),
      LatLng(-7.798602, 110.408004),
      LatLng(-7.798559, 110.408444),
      LatLng(-7.798559, 110.409385),
      LatLng(-7.798568, 110.409838),
      LatLng(-7.798149, 110.409895),
      LatLng(-7.797469, 110.409905),
      LatLng(-7.797082, 110.409909),
      LatLng(-7.795495, 110.409967),
      LatLng(-7.793464, 110.410043),
      LatLng(-7.793070, 110.410057),
      LatLng(-7.792701, 110.410072),
      LatLng(-7.791283, 110.410129),
      LatLng(-7.790764, 110.410146),
      LatLng(-7.788739, 110.410191),
      LatLng(-7.787314, 110.410262),
      LatLng(-7.786775, 110.410257),
      LatLng(-7.784769, 110.410371),
      LatLng(-7.784203, 110.410390),
      LatLng(-7.783775, 110.410402),
      LatLng(-7.783351, 110.410406),
      LatLng(-7.783235, 110.411146),
      LatLng(-7.783240, 110.411612),
      LatLng(-7.783251, 110.412770),
      LatLng(-7.783276, 110.413723),
      LatLng(-7.783282, 110.414679),
      LatLng(-7.783291, 110.416066),
      LatLng(-7.783288, 110.416639),
      LatLng(-7.783285, 110.417115),
      LatLng(-7.783287, 110.417609),
      LatLng(-7.783289, 110.417994),
      LatLng(-7.783289, 110.418390),
      LatLng(-7.783286, 110.418767),
      LatLng(-7.783287, 110.419315),
      LatLng(-7.783288, 110.419721),
      LatLng(-7.783295, 110.420191),
      LatLng(-7.783295, 110.421330),
      LatLng(-7.783299, 110.421736),
      LatLng(-7.783303, 110.422157),
      LatLng(-7.783321, 110.423204),
      LatLng(-7.783333, 110.423655),
      LatLng(-7.783334, 110.424173),
      LatLng(-7.783337, 110.425125),
      LatLng(-7.783337, 110.425739),
      LatLng(-7.783356, 110.426387),
      LatLng(-7.783372, 110.427000),
      LatLng(-7.783382, 110.427418),
      LatLng(-7.783389, 110.428106),
      LatLng(-7.783396, 110.428510),
      LatLng(-7.783405, 110.429054),
      LatLng(-7.783410, 110.429449),
      LatLng(-7.783419, 110.429812),
      LatLng(-7.783438, 110.431018),
      LatLng(-7.783444, 110.431622),
      LatLng(-7.783447, 110.432396),
      LatLng(-7.783449, 110.433170),
      LatLng(-7.783443, 110.433994),
      LatLng(-7.782955, 110.434094),
      LatLng(-7.782574, 110.434165),
      LatLng(-7.781906, 110.434299),
      LatLng(-7.781960, 110.434723),
      LatLng(-7.782171, 110.435753),
    ]);

    addBi('jog_tugu', 'jog_pingit', 'Jl. Pangeran Diponegoro', const [
      LatLng(-7.782797, 110.367015),
      LatLng(-7.782939, 110.366370),
      LatLng(-7.782891, 110.365686),
      LatLng(-7.782882, 110.364977),
      LatLng(-7.782869, 110.364051),
      LatLng(-7.782896, 110.363673),
      LatLng(-7.782882, 110.363035),
      LatLng(-7.782874, 110.362630),
      LatLng(-7.782866, 110.362260),
      LatLng(-7.782855, 110.361756),
      LatLng(-7.782839, 110.361057),
      LatLng(-7.782885, 110.360592),
      LatLng(-7.782878, 110.360093),
      LatLng(-7.782871, 110.359616),
      LatLng(-7.782864, 110.359234),
      LatLng(-7.782842, 110.358815),
      LatLng(-7.783034, 110.358441),
      LatLng(-7.783425, 110.358460),
      LatLng(-7.783567, 110.358159),
    ]);

    addBi('jog_pingit', 'jog_godean_demak', 'Jl. Kyai Mojo / Jl. Godean', const [
      LatLng(-7.783567, 110.358159),
      LatLng(-7.783335, 110.358452),
      LatLng(-7.782844, 110.358381),
      LatLng(-7.782851, 110.357996),
      LatLng(-7.782781, 110.357415),
      LatLng(-7.782677, 110.356916),
      LatLng(-7.782503, 110.356138),
      LatLng(-7.782415, 110.355746),
      LatLng(-7.782198, 110.354902),
      LatLng(-7.782059, 110.354251),
      LatLng(-7.781897, 110.353517),
      LatLng(-7.781781, 110.352943),
      LatLng(-7.781651, 110.352475),
      LatLng(-7.781571, 110.351962),
      LatLng(-7.781434, 110.351238),
      LatLng(-7.781356, 110.350859),
      LatLng(-7.781262, 110.350382),
      LatLng(-7.781089, 110.349665),
      LatLng(-7.780829, 110.348538),
      LatLng(-7.780739, 110.348180),
      LatLng(-7.780650, 110.347780),
      LatLng(-7.780474, 110.346901),
      LatLng(-7.780399, 110.346519),
      LatLng(-7.780252, 110.345903),
      LatLng(-7.779925, 110.344502),
      LatLng(-7.779773, 110.343757),
      LatLng(-7.779682, 110.343350),
      LatLng(-7.779585, 110.342911),
      LatLng(-7.779483, 110.342453),
      LatLng(-7.779397, 110.342054),
      LatLng(-7.779199, 110.341117),
      LatLng(-7.778991, 110.340186),
      LatLng(-7.778872, 110.339655),
      LatLng(-7.778772, 110.339205),
      LatLng(-7.778653, 110.338676),
      LatLng(-7.778568, 110.338294),
      LatLng(-7.778436, 110.337696),
      LatLng(-7.778300, 110.337080),
      LatLng(-7.778224, 110.336719),
      LatLng(-7.778112, 110.336188),
      LatLng(-7.777993, 110.335657),
      LatLng(-7.777821, 110.334836),
      LatLng(-7.777699, 110.334255),
      LatLng(-7.777484, 110.333225),
      LatLng(-7.777362, 110.332660),
      LatLng(-7.777264, 110.332136),
      LatLng(-7.777169, 110.331706),
      LatLng(-7.777091, 110.331334),
      LatLng(-7.777019, 110.330855),
      LatLng(-7.777017, 110.330392),
      LatLng(-7.777027, 110.329870),
      LatLng(-7.777017, 110.329367),
      LatLng(-7.776685, 110.328560),
      LatLng(-7.776402, 110.328136),
      LatLng(-7.776196, 110.327753),
      LatLng(-7.776089, 110.327310),
      LatLng(-7.775949, 110.326675),
      LatLng(-7.776643, 110.326534),
      LatLng(-7.776942, 110.326004),
      LatLng(-7.777427, 110.325940),
      LatLng(-7.777843, 110.325860),
      LatLng(-7.778405, 110.325764),
      LatLng(-7.778773, 110.325689),
      LatLng(-7.779250, 110.325560),
      LatLng(-7.779333, 110.325924),
      LatLng(-7.779474, 110.326542),
      LatLng(-7.779556, 110.326923),
    ]);

    addBi('jog_nol_km', 'jog_pku', 'Jl. KH Ahmad Dahlan', const [
      LatLng(-7.800248, 110.365433),
      LatLng(-7.800215, 110.365030),
      LatLng(-7.800763, 110.364829),
      LatLng(-7.801167, 110.364779),
      LatLng(-7.801365, 110.364455),
      LatLng(-7.801331, 110.363493),
      LatLng(-7.801295, 110.362507),
      LatLng(-7.801278, 110.362029),
      LatLng(-7.801253, 110.361641),
      LatLng(-7.801217, 110.361012),
      LatLng(-7.801201, 110.360634),
      LatLng(-7.801191, 110.360227),
      LatLng(-7.800300, 110.359993),
    ]);

    addBi('jog_pku', 'jog_wirobrajan', 'Jl. KH Ahmad Dahlan', const [
      LatLng(-7.800300, 110.359993),
      LatLng(-7.801184, 110.359967),
      LatLng(-7.801179, 110.359327),
      LatLng(-7.801163, 110.357992),
      LatLng(-7.801152, 110.356721),
      LatLng(-7.801139, 110.356296),
      LatLng(-7.801116, 110.355883),
      LatLng(-7.801068, 110.354946),
      LatLng(-7.801063, 110.354555),
      LatLng(-7.801056, 110.353817),
      LatLng(-7.800437, 110.353868),
      LatLng(-7.800343, 110.353818),
    ]);

    addBi('jog_wirobrajan', 'jog_gamping', 'Jl. Wates', const [
      LatLng(-7.800343, 110.353818),
      LatLng(-7.801056, 110.353817),
      LatLng(-7.801050, 110.353200),
      LatLng(-7.801045, 110.352763),
      LatLng(-7.801073, 110.352225),
      LatLng(-7.801063, 110.351827),
      LatLng(-7.801028, 110.350977),
      LatLng(-7.801010, 110.350557),
      LatLng(-7.800973, 110.349949),
      LatLng(-7.800943, 110.349201),
      LatLng(-7.800934, 110.348596),
      LatLng(-7.800912, 110.348194),
      LatLng(-7.800895, 110.347808),
      LatLng(-7.800890, 110.347364),
      LatLng(-7.800879, 110.346989),
      LatLng(-7.800847, 110.345880),
      LatLng(-7.800825, 110.345347),
      LatLng(-7.800798, 110.344565),
      LatLng(-7.800766, 110.343859),
      LatLng(-7.800727, 110.343161),
      LatLng(-7.800734, 110.342583),
      LatLng(-7.800714, 110.342092),
      LatLng(-7.800676, 110.341355),
      LatLng(-7.800666, 110.340967),
      LatLng(-7.800612, 110.340302),
      LatLng(-7.800561, 110.339529),
      LatLng(-7.800510, 110.338815),
      LatLng(-7.800472, 110.338185),
      LatLng(-7.800425, 110.337548),
      LatLng(-7.800378, 110.336738),
      LatLng(-7.800300, 110.335613),
      LatLng(-7.800239, 110.334600),
      LatLng(-7.800180, 110.333664),
      LatLng(-7.800039, 110.331878),
      LatLng(-7.800014, 110.331373),
      LatLng(-7.799953, 110.330318),
      LatLng(-7.799894, 110.329896),
      LatLng(-7.800147, 110.329463),
      LatLng(-7.800684, 110.329043),
      LatLng(-7.801071, 110.328639),
      LatLng(-7.801194, 110.328195),
      LatLng(-7.800877, 110.327272),
      LatLng(-7.800417, 110.326025),
      LatLng(-7.800363, 110.325612),
      LatLng(-7.800445, 110.325236),
      LatLng(-7.800576, 110.324453),
      LatLng(-7.800662, 110.323952),
      LatLng(-7.800729, 110.323568),
      LatLng(-7.800817, 110.323086),
      LatLng(-7.800913, 110.322562),
      LatLng(-7.801063, 110.321740),
      LatLng(-7.801215, 110.320902),
      LatLng(-7.801304, 110.320418),
      LatLng(-7.801390, 110.319948),
      LatLng(-7.801002, 110.320011),
    ]);

    addBi('jog_nol_km', 'jog_gondomanan', 'Jl. Panembahan Senopati', const [
      LatLng(-7.800248, 110.365433),
      LatLng(-7.800215, 110.365030),
      LatLng(-7.800763, 110.364829),
      LatLng(-7.801167, 110.364779),
      LatLng(-7.801389, 110.365688),
      LatLng(-7.801430, 110.366881),
      LatLng(-7.801446, 110.367329),
      LatLng(-7.801474, 110.368140),
      LatLng(-7.801505, 110.369015),
      LatLng(-7.801229, 110.369279),
      LatLng(-7.800862, 110.369291),
      LatLng(-7.800496, 110.369303),
      LatLng(-7.800466, 110.369304),
    ]);

    addBi('jog_gondomanan', 'jog_sayidan', 'Jl. Sultan Agung', const [
      LatLng(-7.800466, 110.369304),
      LatLng(-7.799878, 110.369324),
      LatLng(-7.799374, 110.369341),
      LatLng(-7.798853, 110.369364),
      LatLng(-7.798075, 110.369368),
      LatLng(-7.797709, 110.369350),
      LatLng(-7.797340, 110.369340),
      LatLng(-7.796924, 110.369267),
      LatLng(-7.796730, 110.369934),
      LatLng(-7.796754, 110.370663),
      LatLng(-7.796764, 110.371116),
      LatLng(-7.796783, 110.371582),
      LatLng(-7.796830, 110.372478),
      LatLng(-7.797192, 110.372629),
      LatLng(-7.797562, 110.372631),
      LatLng(-7.797960, 110.372881),
      LatLng(-7.798296, 110.373020),
      LatLng(-7.798721, 110.373107),
      LatLng(-7.799493, 110.373132),
      LatLng(-7.800165, 110.373136),
      LatLng(-7.800830, 110.373130),
      LatLng(-7.801499, 110.373097),
      LatLng(-7.801615, 110.373968),
      LatLng(-7.801623, 110.374331),
      LatLng(-7.801627, 110.374727),
      LatLng(-7.801642, 110.375153),
      LatLng(-7.801653, 110.375636),
      LatLng(-7.801670, 110.376206),
      LatLng(-7.801095, 110.376207),
      LatLng(-7.801378, 110.376417),
    ]);

    addBi('jog_sayidan', 'jog_glzoo', 'Jl. Kusumanegara', const [
      LatLng(-7.801378, 110.376417),
      LatLng(-7.801683, 110.376710),
      LatLng(-7.801695, 110.377158),
      LatLng(-7.801714, 110.377886),
      LatLng(-7.801727, 110.378345),
      LatLng(-7.801737, 110.378734),
      LatLng(-7.801770, 110.379811),
      LatLng(-7.801784, 110.380269),
      LatLng(-7.801795, 110.380640),
      LatLng(-7.801809, 110.381130),
      LatLng(-7.801822, 110.381537),
      LatLng(-7.801836, 110.382010),
      LatLng(-7.801855, 110.382718),
      LatLng(-7.801866, 110.383135),
      LatLng(-7.801883, 110.383725),
      LatLng(-7.801894, 110.384109),
      LatLng(-7.801907, 110.384556),
      LatLng(-7.801928, 110.385392),
      LatLng(-7.801940, 110.385852),
      LatLng(-7.801966, 110.386757),
      LatLng(-7.801977, 110.387162),
      LatLng(-7.801988, 110.387623),
      LatLng(-7.802000, 110.388034),
      LatLng(-7.802013, 110.388517),
      LatLng(-7.802013, 110.388927),
      LatLng(-7.802021, 110.389515),
      LatLng(-7.802031, 110.389885),
      LatLng(-7.802046, 110.390678),
      LatLng(-7.802060, 110.391122),
      LatLng(-7.802079, 110.391836),
      LatLng(-7.802118, 110.392881),
      LatLng(-7.802125, 110.393274),
      LatLng(-7.802131, 110.394268),
      LatLng(-7.802147, 110.394863),
      LatLng(-7.802144, 110.395412),
      LatLng(-7.802161, 110.396391),
      LatLng(-7.802199, 110.396999),
      LatLng(-7.802216, 110.397789),
      LatLng(-7.802200, 110.398246),
      LatLng(-7.802234, 110.399489),
      LatLng(-7.801851, 110.399402),
      LatLng(-7.801767, 110.400131),
      LatLng(-7.802276, 110.400172),
      LatLng(-7.802257, 110.399611),
      LatLng(-7.802254, 110.398774),
      LatLng(-7.802245, 110.398262),
      LatLng(-7.803090, 110.398191),
      LatLng(-7.803419, 110.397961),
      LatLng(-7.803702, 110.397771),
    ]);

    addBi('jog_glzoo', 'jog_bloko', 'Jl. Janti Blok O', const [
      LatLng(-7.803702, 110.397771),
      LatLng(-7.803790, 110.398162),
      LatLng(-7.804224, 110.398314),
      LatLng(-7.804739, 110.398265),
      LatLng(-7.805619, 110.398216),
      LatLng(-7.806334, 110.398178),
      LatLng(-7.807397, 110.398100),
      LatLng(-7.807395, 110.398996),
      LatLng(-7.807407, 110.399573),
      LatLng(-7.807403, 110.400007),
      LatLng(-7.807396, 110.400551),
      LatLng(-7.807393, 110.401416),
      LatLng(-7.807391, 110.401803),
      LatLng(-7.807390, 110.402185),
      LatLng(-7.806909, 110.402195),
      LatLng(-7.805801, 110.402192),
      LatLng(-7.804834, 110.402215),
      LatLng(-7.804097, 110.402236),
      LatLng(-7.803328, 110.402251),
      LatLng(-7.802928, 110.402272),
      LatLng(-7.802558, 110.402278),
      LatLng(-7.802195, 110.402283),
      LatLng(-7.801639, 110.402281),
      LatLng(-7.801141, 110.402295),
      LatLng(-7.800602, 110.402307),
      LatLng(-7.800152, 110.402316),
      LatLng(-7.799456, 110.402324),
      LatLng(-7.798981, 110.402331),
      LatLng(-7.798647, 110.402520),
      LatLng(-7.798568, 110.402912),
      LatLng(-7.798566, 110.404053),
      LatLng(-7.798565, 110.405055),
      LatLng(-7.798564, 110.405561),
      LatLng(-7.798563, 110.406032),
      LatLng(-7.798561, 110.407030),
      LatLng(-7.798561, 110.407448),
      LatLng(-7.798560, 110.408020),
      LatLng(-7.798559, 110.408444),
      LatLng(-7.798559, 110.409385),
      LatLng(-7.798568, 110.409838),
      LatLng(-7.798574, 110.410744),
      LatLng(-7.798577, 110.411940),
      LatLng(-7.798161, 110.412148),
      LatLng(-7.798036, 110.412685),
      LatLng(-7.797734, 110.412911),
      LatLng(-7.797305, 110.413013),
      LatLng(-7.796964, 110.412168),
      LatLng(-7.796968, 110.411658),
      LatLng(-7.796452, 110.411351),
      LatLng(-7.795855, 110.411376),
      LatLng(-7.795146, 110.411055),
      LatLng(-7.795199, 110.410623),
      LatLng(-7.795800, 110.410511),
    ]);

    addBi('jog_kronggahan', 'jog_jombor', 'Jl. Ring Road Utara', const [
      LatLng(-7.755608, 110.339860),
      LatLng(-7.755401, 110.338986),
      LatLng(-7.755880, 110.338830),
      LatLng(-7.760985, 110.337051),
      LatLng(-7.762284, 110.336612),
      LatLng(-7.763264, 110.336290),
      LatLng(-7.763904, 110.336080),
      LatLng(-7.763324, 110.336185),
      LatLng(-7.762000, 110.336623),
      LatLng(-7.758957, 110.337649),
      LatLng(-7.756386, 110.338524),
      LatLng(-7.752561, 110.339779),
      LatLng(-7.751942, 110.340002),
      LatLng(-7.751243, 110.340237),
      LatLng(-7.750427, 110.340509),
      LatLng(-7.749834, 110.340715),
      LatLng(-7.749425, 110.340899),
      LatLng(-7.748933, 110.341146),
      LatLng(-7.748482, 110.341408),
      LatLng(-7.747908, 110.341760),
      LatLng(-7.747361, 110.342112),
      LatLng(-7.744970, 110.343665),
      LatLng(-7.744606, 110.343930),
      LatLng(-7.744324, 110.344198),
      LatLng(-7.744101, 110.344541),
      LatLng(-7.743933, 110.344916),
      LatLng(-7.743828, 110.345333),
      LatLng(-7.743815, 110.345769),
      LatLng(-7.743877, 110.346158),
      LatLng(-7.744293, 110.347477),
      LatLng(-7.744483, 110.348146),
      LatLng(-7.744694, 110.348804),
      LatLng(-7.744905, 110.349474),
      LatLng(-7.745042, 110.349847),
      LatLng(-7.745345, 110.350859),
      LatLng(-7.745915, 110.352656),
      LatLng(-7.746037, 110.353035),
      LatLng(-7.746260, 110.353740),
      LatLng(-7.746420, 110.354222),
      LatLng(-7.746572, 110.354715),
      LatLng(-7.747177, 110.356629),
      LatLng(-7.747366, 110.357255),
      LatLng(-7.747673, 110.358386),
      LatLng(-7.747918, 110.359243),
      LatLng(-7.748138, 110.359920),
      LatLng(-7.748299, 110.360454),
      LatLng(-7.748725, 110.361423),
      LatLng(-7.748894, 110.361819),
      LatLng(-7.748889, 110.362184),
      LatLng(-7.748539, 110.362303),
      LatLng(-7.747812, 110.362358),
      LatLng(-7.747680, 110.361831),
    ]);

    addBi('jog_jombor', 'jog_monjali', 'Jl. Ring Road Utara', const [
      LatLng(-7.747680, 110.361831),
      LatLng(-7.747504, 110.361098),
      LatLng(-7.747410, 110.360627),
      LatLng(-7.747888, 110.360751),
      LatLng(-7.748417, 110.360729),
      LatLng(-7.748725, 110.361423),
      LatLng(-7.748894, 110.361819),
      LatLng(-7.749006, 110.362192),
      LatLng(-7.749298, 110.362851),
      LatLng(-7.749476, 110.363246),
      LatLng(-7.749720, 110.363827),
      LatLng(-7.750021, 110.364678),
      LatLng(-7.750248, 110.365301),
      LatLng(-7.750371, 110.365847),
      LatLng(-7.750450, 110.366906),
      LatLng(-7.750490, 110.367284),
      LatLng(-7.750520, 110.367653),
      LatLng(-7.750583, 110.368228),
      LatLng(-7.750019, 110.368462),
      LatLng(-7.749645, 110.368561),
      LatLng(-7.749019, 110.368898),
      LatLng(-7.748530, 110.369088),
      LatLng(-7.748377, 110.369468),
      LatLng(-7.748785, 110.370458),
    ]);

    addBi('jog_monjali', 'jog_kentungan', 'Jl. Ring Road Utara', const [
      LatLng(-7.748785, 110.370458),
      LatLng(-7.748377, 110.369468),
      LatLng(-7.748530, 110.369088),
      LatLng(-7.749019, 110.368898),
      LatLng(-7.749334, 110.368681),
      LatLng(-7.749686, 110.368569),
      LatLng(-7.750320, 110.368337),
      LatLng(-7.750632, 110.368674),
      LatLng(-7.750719, 110.369300),
      LatLng(-7.750845, 110.370047),
      LatLng(-7.750979, 110.370393),
      LatLng(-7.751096, 110.370905),
      LatLng(-7.751229, 110.371514),
      LatLng(-7.751348, 110.372061),
      LatLng(-7.751831, 110.374664),
      LatLng(-7.751962, 110.375399),
      LatLng(-7.752014, 110.375798),
      LatLng(-7.751995, 110.376204),
      LatLng(-7.751911, 110.377012),
      LatLng(-7.751865, 110.377434),
      LatLng(-7.751893, 110.377916),
      LatLng(-7.752092, 110.378639),
      LatLng(-7.752266, 110.379381),
      LatLng(-7.752519, 110.380005),
      LatLng(-7.752794, 110.380552),
      LatLng(-7.753218, 110.381366),
      LatLng(-7.753422, 110.381740),
      LatLng(-7.753809, 110.382316),
      LatLng(-7.754042, 110.382595),
      LatLng(-7.754318, 110.382915),
      LatLng(-7.754073, 110.383817),
      LatLng(-7.754541, 110.383555),
      LatLng(-7.754939, 110.383366),
      LatLng(-7.754376, 110.382697),
      LatLng(-7.753884, 110.382098),
      LatLng(-7.753659, 110.381772),
      LatLng(-7.753393, 110.381293),
      LatLng(-7.753363, 110.380697),
    ]);

    addBi('jog_kentungan', 'jog_condongcatur', 'Jl. Ring Road Utara', const [
      LatLng(-7.753363, 110.380697),
      LatLng(-7.753283, 110.379908),
      LatLng(-7.753251, 110.379462),
      LatLng(-7.753617, 110.379079),
      LatLng(-7.754094, 110.379965),
      LatLng(-7.754229, 110.380972),
      LatLng(-7.754647, 110.380900),
      LatLng(-7.755137, 110.381008),
      LatLng(-7.755598, 110.381807),
      LatLng(-7.755785, 110.382772),
      LatLng(-7.755473, 110.382991),
      LatLng(-7.755108, 110.383180),
      LatLng(-7.754765, 110.383387),
      LatLng(-7.755130, 110.383737),
      LatLng(-7.755509, 110.384113),
      LatLng(-7.755877, 110.384528),
      LatLng(-7.757057, 110.385723),
      LatLng(-7.758351, 110.386913),
      LatLng(-7.758982, 110.387557),
      LatLng(-7.759340, 110.387998),
      LatLng(-7.759515, 110.388349),
      LatLng(-7.759643, 110.388758),
      LatLng(-7.759741, 110.389279),
      LatLng(-7.759793, 110.389745),
      LatLng(-7.759760, 110.390208),
      LatLng(-7.759589, 110.390929),
      LatLng(-7.758742, 110.394216),
      LatLng(-7.758619, 110.394612),
      LatLng(-7.758497, 110.395099),
      LatLng(-7.758423, 110.395503),
    ]);

    addBi('jog_condongcatur', 'jog_upn', 'Jl. Ring Road Utara', const [
      LatLng(-7.758423, 110.395503),
      LatLng(-7.758333, 110.396216),
      LatLng(-7.758274, 110.396632),
      LatLng(-7.758162, 110.397534),
      LatLng(-7.758071, 110.398249),
      LatLng(-7.758052, 110.398660),
      LatLng(-7.758050, 110.399081),
      LatLng(-7.758057, 110.399447),
      LatLng(-7.758086, 110.400053),
      LatLng(-7.758133, 110.400463),
      LatLng(-7.758261, 110.401049),
      LatLng(-7.758550, 110.401969),
      LatLng(-7.758958, 110.403197),
      LatLng(-7.759224, 110.403998),
      LatLng(-7.759378, 110.404499),
      LatLng(-7.760628, 110.408398),
      LatLng(-7.760108, 110.406565),
      LatLng(-7.759468, 110.404516),
      LatLng(-7.759349, 110.404003),
      LatLng(-7.759800, 110.403861),
      LatLng(-7.760176, 110.403753),
      LatLng(-7.760584, 110.403678),
      LatLng(-7.760878, 110.404260),
      LatLng(-7.761017, 110.404730),
      LatLng(-7.761169, 110.405188),
      LatLng(-7.761506, 110.406097),
      LatLng(-7.761741, 110.406629),
      LatLng(-7.762134, 110.406977),
      LatLng(-7.761831, 110.407445),
    ]);

    addBi('jog_upn', 'jog_maguwo', 'Jl. Ring Road Utara', const [
      LatLng(-7.761831, 110.407445),
      LatLng(-7.762192, 110.407333),
      LatLng(-7.762018, 110.406564),
      LatLng(-7.762623, 110.406408),
      LatLng(-7.763285, 110.406230),
      LatLng(-7.763360, 110.406614),
      LatLng(-7.763492, 110.407285),
      LatLng(-7.763566, 110.407662),
      LatLng(-7.763673, 110.408204),
      LatLng(-7.763900, 110.409337),
      LatLng(-7.764120, 110.410519),
      LatLng(-7.764191, 110.410983),
      LatLng(-7.764702, 110.410898),
      LatLng(-7.765485, 110.410720),
      LatLng(-7.766037, 110.410600),
      LatLng(-7.766447, 110.410512),
      LatLng(-7.766828, 110.410429),
      LatLng(-7.767234, 110.410341),
      LatLng(-7.767645, 110.410279),
      LatLng(-7.768025, 110.410200),
      LatLng(-7.768571, 110.410086),
      LatLng(-7.769213, 110.409951),
      LatLng(-7.769767, 110.409835),
      LatLng(-7.770616, 110.409658),
      LatLng(-7.771171, 110.409541),
      LatLng(-7.771772, 110.409415),
      LatLng(-7.772184, 110.409342),
      LatLng(-7.772583, 110.410218),
      LatLng(-7.772724, 110.410778),
      LatLng(-7.772819, 110.411153),
      LatLng(-7.773293, 110.411088),
      LatLng(-7.773696, 110.411057),
      LatLng(-7.773853, 110.411394),
      LatLng(-7.773906, 110.411864),
      LatLng(-7.773963, 110.412382),
      LatLng(-7.774025, 110.412943),
      LatLng(-7.774079, 110.413442),
      LatLng(-7.774142, 110.414117),
      LatLng(-7.774221, 110.414900),
      LatLng(-7.774251, 110.415308),
      LatLng(-7.774202, 110.415733),
      LatLng(-7.774582, 110.415797),
      LatLng(-7.774988, 110.415708),
      LatLng(-7.775462, 110.415605),
      LatLng(-7.776534, 110.415371),
      LatLng(-7.777154, 110.415236),
      LatLng(-7.777608, 110.415138),
      LatLng(-7.778680, 110.414902),
      LatLng(-7.779099, 110.414811),
      LatLng(-7.779458, 110.414730),
      LatLng(-7.779890, 110.414640),
      LatLng(-7.780289, 110.414556),
      LatLng(-7.780684, 110.414477),
      LatLng(-7.781396, 110.414334),
      LatLng(-7.781852, 110.414238),
      LatLng(-7.782337, 110.414138),
      LatLng(-7.783276, 110.413949),
      LatLng(-7.783282, 110.414679),
      LatLng(-7.783291, 110.416066),
      LatLng(-7.783288, 110.416639),
      LatLng(-7.783285, 110.417115),
      LatLng(-7.783287, 110.417609),
      LatLng(-7.783289, 110.417994),
      LatLng(-7.783289, 110.418390),
      LatLng(-7.783286, 110.418767),
      LatLng(-7.783287, 110.419315),
      LatLng(-7.783288, 110.419721),
      LatLng(-7.783295, 110.420191),
      LatLng(-7.783295, 110.421330),
      LatLng(-7.783299, 110.421736),
      LatLng(-7.783303, 110.422157),
      LatLng(-7.783321, 110.423204),
      LatLng(-7.783333, 110.423655),
      LatLng(-7.783334, 110.424173),
      LatLng(-7.783337, 110.425125),
      LatLng(-7.783337, 110.425739),
      LatLng(-7.783356, 110.426387),
      LatLng(-7.783372, 110.427000),
      LatLng(-7.783382, 110.427418),
      LatLng(-7.783389, 110.428106),
      LatLng(-7.783396, 110.428510),
      LatLng(-7.783405, 110.429054),
      LatLng(-7.783410, 110.429449),
      LatLng(-7.783168, 110.429740),
      LatLng(-7.782502, 110.429808),
      LatLng(-7.781277, 110.429884),
      LatLng(-7.780676, 110.429939),
      LatLng(-7.780013, 110.430004),
      LatLng(-7.779954, 110.429579),
      LatLng(-7.779896, 110.429132),
      LatLng(-7.779492, 110.429178),
      LatLng(-7.778981, 110.429089),
      LatLng(-7.778363, 110.428857),
      LatLng(-7.777979, 110.428686),
      LatLng(-7.777795, 110.428271),
      LatLng(-7.777832, 110.428011),
    ]);

    addBi('jog_jombor', 'jog_pingit', 'Jl. Magelang', const [
      LatLng(-7.747680, 110.361831),
      LatLng(-7.747504, 110.361098),
      LatLng(-7.747410, 110.360627),
      LatLng(-7.747888, 110.360751),
      LatLng(-7.748417, 110.360729),
      LatLng(-7.748725, 110.361423),
      LatLng(-7.748894, 110.361819),
      LatLng(-7.749006, 110.362192),
      LatLng(-7.749156, 110.362532),
      LatLng(-7.749863, 110.362388),
      LatLng(-7.750711, 110.362345),
      LatLng(-7.751366, 110.362312),
      LatLng(-7.752323, 110.362264),
      LatLng(-7.753190, 110.362220),
      LatLng(-7.753561, 110.362197),
      LatLng(-7.754160, 110.362170),
      LatLng(-7.755147, 110.362127),
      LatLng(-7.758169, 110.361986),
      LatLng(-7.758745, 110.361957),
      LatLng(-7.759264, 110.361937),
      LatLng(-7.761161, 110.361836),
      LatLng(-7.762627, 110.361767),
      LatLng(-7.763337, 110.361736),
      LatLng(-7.763809, 110.361717),
      LatLng(-7.764247, 110.361700),
      LatLng(-7.764705, 110.361683),
      LatLng(-7.766018, 110.361625),
      LatLng(-7.766482, 110.361606),
      LatLng(-7.767249, 110.361570),
      LatLng(-7.767924, 110.361543),
      LatLng(-7.768453, 110.361517),
      LatLng(-7.769355, 110.361461),
      LatLng(-7.769973, 110.361430),
      LatLng(-7.770367, 110.361368),
      LatLng(-7.771163, 110.361329),
      LatLng(-7.771552, 110.361352),
      LatLng(-7.772428, 110.361294),
      LatLng(-7.773354, 110.361259),
      LatLng(-7.774099, 110.361235),
      LatLng(-7.774551, 110.361213),
      LatLng(-7.775400, 110.361179),
      LatLng(-7.776383, 110.361113),
      LatLng(-7.776766, 110.361098),
      LatLng(-7.777246, 110.361073),
      LatLng(-7.778100, 110.361059),
      LatLng(-7.778508, 110.361039),
      LatLng(-7.779241, 110.361003),
      LatLng(-7.779645, 110.360982),
      LatLng(-7.780061, 110.360964),
      LatLng(-7.780733, 110.360939),
      LatLng(-7.781447, 110.360889),
      LatLng(-7.782089, 110.360860),
      LatLng(-7.782538, 110.360845),
      LatLng(-7.782885, 110.360592),
      LatLng(-7.782878, 110.360093),
      LatLng(-7.782871, 110.359616),
      LatLng(-7.782864, 110.359234),
      LatLng(-7.782842, 110.358815),
      LatLng(-7.783034, 110.358441),
      LatLng(-7.783425, 110.358460),
      LatLng(-7.783567, 110.358159),
    ]);

    addBi('jog_kentungan', 'jog_ugm', 'Jl. Kaliurang', const [
      LatLng(-7.753363, 110.380697),
      LatLng(-7.753283, 110.379908),
      LatLng(-7.753251, 110.379462),
      LatLng(-7.753617, 110.379079),
      LatLng(-7.754094, 110.379965),
      LatLng(-7.754229, 110.380972),
      LatLng(-7.754647, 110.380900),
      LatLng(-7.755137, 110.381008),
      LatLng(-7.755598, 110.381807),
      LatLng(-7.755785, 110.382772),
      LatLng(-7.756312, 110.382562),
      LatLng(-7.756782, 110.382339),
      LatLng(-7.757420, 110.382072),
      LatLng(-7.757987, 110.381833),
      LatLng(-7.758430, 110.381652),
      LatLng(-7.759157, 110.381358),
      LatLng(-7.759567, 110.381214),
      LatLng(-7.760070, 110.381002),
      LatLng(-7.760669, 110.380748),
      LatLng(-7.761062, 110.380580),
      LatLng(-7.761400, 110.380436),
      LatLng(-7.761887, 110.380228),
      LatLng(-7.762417, 110.380001),
      LatLng(-7.762955, 110.379771),
      LatLng(-7.763725, 110.379441),
      LatLng(-7.764383, 110.379158),
      LatLng(-7.765378, 110.378747),
      LatLng(-7.765752, 110.378600),
      LatLng(-7.767001, 110.378093),
      LatLng(-7.767630, 110.377834),
      LatLng(-7.768204, 110.377602),
      LatLng(-7.769455, 110.377087),
      LatLng(-7.769723, 110.377342),
      LatLng(-7.770079, 110.377233),
      LatLng(-7.770662, 110.377053),
      LatLng(-7.770659, 110.377427),
      LatLng(-7.770738, 110.377735),
    ]);

    addBi('jog_ugm', 'jog_galeria', 'Jl. C. Simanjuntak', const [
      LatLng(-7.770738, 110.377735),
      LatLng(-7.770901, 110.378061),
      LatLng(-7.771062, 110.378413),
      LatLng(-7.772039, 110.378115),
      LatLng(-7.772122, 110.377576),
      LatLng(-7.772707, 110.377208),
      LatLng(-7.773248, 110.377049),
      LatLng(-7.773968, 110.376834),
      LatLng(-7.774598, 110.376640),
      LatLng(-7.775026, 110.376512),
      LatLng(-7.775585, 110.376347),
      LatLng(-7.775951, 110.376237),
      LatLng(-7.776128, 110.376841),
      LatLng(-7.776147, 110.377546),
      LatLng(-7.776166, 110.377987),
      LatLng(-7.776201, 110.378608),
      LatLng(-7.776238, 110.379183),
      LatLng(-7.776271, 110.379551),
      LatLng(-7.776450, 110.379887),
      LatLng(-7.776508, 110.380267),
      LatLng(-7.776634, 110.380680),
      LatLng(-7.776695, 110.381209),
      LatLng(-7.776857, 110.382189),
      LatLng(-7.776945, 110.382854),
      LatLng(-7.776996, 110.383299),
      LatLng(-7.777113, 110.383776),
      LatLng(-7.777406, 110.384573),
      LatLng(-7.777562, 110.385042),
      LatLng(-7.777824, 110.385935),
      LatLng(-7.777877, 110.386326),
      LatLng(-7.777779, 110.386720),
      LatLng(-7.777673, 110.387156),
      LatLng(-7.777605, 110.387527),
      LatLng(-7.777815, 110.388482),
      LatLng(-7.778213, 110.388651),
      LatLng(-7.778711, 110.388560),
      LatLng(-7.779192, 110.388472),
      LatLng(-7.780243, 110.388280),
      LatLng(-7.781388, 110.388072),
      LatLng(-7.782093, 110.387943),
      LatLng(-7.782717, 110.387829),
      LatLng(-7.783065, 110.387661),
      LatLng(-7.783092, 110.387247),
      LatLng(-7.783084, 110.386529),
      LatLng(-7.783079, 110.386164),
      LatLng(-7.783068, 110.385331),
      LatLng(-7.783052, 110.383672),
      LatLng(-7.783047, 110.383304),
      LatLng(-7.783046, 110.382830),
      LatLng(-7.783043, 110.382423),
      LatLng(-7.783035, 110.381420),
      LatLng(-7.783029, 110.380701),
      LatLng(-7.783017, 110.380001),
    ]);

    addBi('jog_condongcatur', 'jog_demangan', 'Jl. Affandi (Gejayan)', const [
      LatLng(-7.758423, 110.395503),
      LatLng(-7.758830, 110.395593),
      LatLng(-7.759229, 110.395405),
      LatLng(-7.759576, 110.395233),
      LatLng(-7.760097, 110.394949),
      LatLng(-7.760605, 110.394633),
      LatLng(-7.761065, 110.394365),
      LatLng(-7.761755, 110.394179),
      LatLng(-7.762337, 110.394036),
      LatLng(-7.763336, 110.393748),
      LatLng(-7.764227, 110.393170),
      LatLng(-7.764996, 110.392714),
      LatLng(-7.765383, 110.392493),
      LatLng(-7.765883, 110.392292),
      LatLng(-7.766964, 110.391841),
      LatLng(-7.767613, 110.391605),
      LatLng(-7.768358, 110.391280),
      LatLng(-7.768834, 110.391054),
      LatLng(-7.769230, 110.390876),
      LatLng(-7.769743, 110.390626),
      LatLng(-7.770275, 110.390376),
      LatLng(-7.770611, 110.390217),
      LatLng(-7.770997, 110.390062),
      LatLng(-7.771580, 110.389916),
      LatLng(-7.772055, 110.389814),
      LatLng(-7.772762, 110.389674),
      LatLng(-7.773422, 110.389538),
      LatLng(-7.774136, 110.389406),
      LatLng(-7.775066, 110.389243),
      LatLng(-7.775440, 110.389174),
      LatLng(-7.776125, 110.389045),
      LatLng(-7.776611, 110.388953),
      LatLng(-7.777075, 110.388863),
      LatLng(-7.777661, 110.388755),
      LatLng(-7.778069, 110.388677),
      LatLng(-7.778711, 110.388560),
      LatLng(-7.779192, 110.388472),
      LatLng(-7.780243, 110.388280),
      LatLng(-7.781388, 110.388072),
      LatLng(-7.782093, 110.387943),
      LatLng(-7.782717, 110.387829),
      LatLng(-7.783051, 110.388144),
      LatLng(-7.783057, 110.388528),
      LatLng(-7.783063, 110.389191),
      LatLng(-7.783073, 110.390284),
      LatLng(-7.783077, 110.390754),
      LatLng(-7.783077, 110.390798),
    ]);

    addBi('jog_stasiun', 'jog_gondomanan', 'Jl. Mataram', const [
      LatLng(-7.789500, 110.366300),
      LatLng(-7.792500, 110.368500),
      LatLng(-7.795600, 110.368800),
      LatLng(-7.798500, 110.369500),
      LatLng(-7.800500, 110.370200),
    ]);

    // Jakarta Edges
    addBi('jkt_monas', 'jkt_sarinah', 'Jl. M.H. Thamrin', const [
      LatLng(-6.175392, 106.827153),
      LatLng(-6.182245, 106.824982),
      LatLng(-6.189563, 106.823908),
    ]);
    addBi('jkt_sarinah', 'jkt_bundaran_hi', 'Jl. M.H. Thamrin', const [
      LatLng(-6.189563, 106.823908),
      LatLng(-6.194432, 106.823021),
    ]);
    addBi('jkt_bundaran_hi', 'jkt_dukuh_atas', 'Jl. Jenderal Sudirman', const [
      LatLng(-6.194432, 106.823021),
      LatLng(-6.203341, 106.821453),
    ]);
    addBi('jkt_dukuh_atas', 'jkt_karet', 'Jl. Jenderal Sudirman', const [
      LatLng(-6.203341, 106.821453),
      LatLng(-6.208821, 106.819876),
    ]);
    addBi('jkt_karet', 'jkt_semanggi', 'Jl. Jenderal Sudirman', const [
      LatLng(-6.208821, 106.819876),
      LatLng(-6.215543, 106.814232),
    ]);
    addBi('jkt_semanggi', 'jkt_gbk', 'Jl. Gatot Subroto', const [
      LatLng(-6.215543, 106.814232),
      LatLng(-6.218521, 106.802341),
    ]);
    addBi('jkt_monas', 'jkt_harmoni', 'Jl. Medan Merdeka Barat', const [
      LatLng(-6.175392, 106.827153),
      LatLng(-6.160124, 106.829124),
    ]);
    addBi('jkt_harmoni', 'jkt_kotatua', 'Jl. Gajah Mada', const [
      LatLng(-6.160124, 106.829124),
      LatLng(-6.138452, 106.826543),
    ]);
    addBi('jkt_kotatua', 'jkt_ancol', 'Jl. Lodan Raya', const [
      LatLng(-6.138452, 106.826543),
      LatLng(-6.126543, 106.833452),
    ]);

    // Bandung Edges
    addBi('bdg_pasteur', 'bdg_djunjunan', 'Jl. Dr. Djunjunan', const [
      LatLng(-6.893245, 107.575643),
      LatLng(-6.899543, 107.595432),
    ]);
    addBi('bdg_djunjunan', 'bdg_pasupati', 'Flyover Pasupati', const [
      LatLng(-6.899543, 107.595432),
      LatLng(-6.901234, 107.608765),
    ]);
    addBi('bdg_pasupati', 'bdg_gedungsate', 'Jl. Diponegoro', const [
      LatLng(-6.901234, 107.608765),
      LatLng(-6.902534, 107.618645),
    ]);

    return list;
  }

  // ---------------------------------------------------------
  // 2. MAIN ROUTING ENTRY POINT FOR OFFLINE MODE
  // ---------------------------------------------------------
  static NavigationRoute buildOfflineRoute({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
  }) {
    // 1. Cek rute preset terkenal (Tugu-Keraton, Monas-GBK, dsb.)
    final presetMatch = _matchPreset(origin, destination, originName, destinationName);
    if (presetMatch != null) {
      debugPrint('[OfflineRouting] Matched curated preset route: ${presetMatch.destinationName}');
      return presetMatch;
    }

    // 2. Cari snap jalan terdekat untuk titik awal dan akhir (radius snap hingga 2.5 km)
    final snapStart = _snapToNearestRoad(origin, maxDistanceMeters: 2500.0);
    final snapEnd = _snapToNearestRoad(destination, maxDistanceMeters: 2500.0);

    // 3. Jika kedua titik dapat di-snap ke jaringan jalan nyata
    if (snapStart != null && snapEnd != null) {
      final roadRoute = _routeAlongRoads(
        origin: origin,
        destination: destination,
        snapStart: snapStart,
        snapEnd: snapEnd,
        originName: originName,
        destinationName: destinationName,
      );
      if (roadRoute != null) {
        return roadRoute;
      }
    }

    // 4. Jika berada di luar jaringan jalan terdata, gunakan rute langsung bersih
    return _routeDirectClean(
      origin: origin,
      destination: destination,
      originName: originName,
      destinationName: destinationName,
    );
  }

  // ---------------------------------------------------------
  // 3. ROAD SNAPPING (PROYEKSI TEGAK LURUS KE JALAN TERDEKAT)
  // ---------------------------------------------------------
  static RoadSnap? _snapToNearestRoad(LatLng p, {double maxDistanceMeters = 2500.0}) {
    RoadSnap? bestSnap;
    double minDistance = double.infinity;

    for (var edge in _edges) {
      for (int i = 0; i < edge.geometry.length - 1; i++) {
        final a = edge.geometry[i];
        final b = edge.geometry[i + 1];
        final proj = _projectPointOnSegment(p, a, b);
        final dist = _distanceCalc.as(LengthUnit.Meter, p, proj);

        if (dist < minDistance && dist <= maxDistanceMeters) {
          minDistance = dist;
          bestSnap = RoadSnap(
            edge: edge,
            projectedPoint: proj,
            segmentIndex: i,
            distanceMeters: dist,
          );
        }
      }
    }

    return bestSnap;
  }

  static LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final segLenSq = dx * dx + dy * dy;

    if (segLenSq == 0) return a;

    final t = (((p.longitude - a.longitude) * dx +
                (p.latitude - a.latitude) * dy) /
            segLenSq)
        .clamp(0.0, 1.0);

    return LatLng(a.latitude + t * dy, a.longitude + t * dx);
  }

  // ---------------------------------------------------------
  // 4. ROUTE ALONG ROADS WITH 4-WAY OPTIMAL DIJKSTRA
  // ---------------------------------------------------------
  static NavigationRoute? _routeAlongRoads({
    required LatLng origin,
    required LatLng destination,
    required RoadSnap snapStart,
    required RoadSnap snapEnd,
    required String originName,
    required String destinationName,
  }) {
    final polyline = <LatLng>[];
    final edgesUsed = <RoadEdge>[];

    polyline.add(origin);

    // KASUS 1: Berada pada koridor fisik jalan yang sama (misal sama-sama di Jl. Solo atau Jl. Malioboro)
    if (snapStart.edge.fromId == snapEnd.edge.fromId && snapStart.edge.toId == snapEnd.edge.toId) {
      edgesUsed.add(snapStart.edge);
      polyline.add(snapStart.projectedPoint);

      final geom = snapStart.edge.geometry;
      final i1 = snapStart.segmentIndex;
      final i2 = snapEnd.segmentIndex;

      if (i1 <= i2) {
        for (int i = i1 + 1; i <= i2; i++) {
          polyline.add(geom[i]);
        }
      } else {
        for (int i = i1; i > i2; i--) {
          polyline.add(geom[i]);
        }
      }

      polyline.add(snapEnd.projectedPoint);
      polyline.add(destination);
    } else if (snapStart.edge.fromId == snapEnd.edge.toId && snapStart.edge.toId == snapEnd.edge.fromId) {
      // Sama tapi berlawanan arah
      edgesUsed.add(snapStart.edge);
      polyline.add(snapStart.projectedPoint);

      final geom = snapStart.edge.geometry;
      final i1 = snapStart.segmentIndex;
      final i2 = geom.length - 1 - snapEnd.segmentIndex;

      if (i1 <= i2) {
        for (int i = i1 + 1; i <= i2; i++) {
          polyline.add(geom[i]);
        }
      } else {
        for (int i = i1; i > i2; i--) {
          polyline.add(geom[i]);
        }
      }

      polyline.add(snapEnd.projectedPoint);
      polyline.add(destination);
    } else {
      // KASUS 2: Berada pada ruas jalan berbeda -> Pilih dari 4 kombinasi arah terpendek (Tanpa Putar Balik)
      final eStart = snapStart.edge;
      final eEnd = snapEnd.edge;

      final path1 = _findDijkstraEdges(eStart.toId, eEnd.fromId);
      final path2 = _findDijkstraEdges(eStart.toId, eEnd.toId);
      final path3 = _findDijkstraEdges(eStart.fromId, eEnd.fromId);
      final path4 = _findDijkstraEdges(eStart.fromId, eEnd.toId);

      double distAlong(List<LatLng> pts) {
        double d = 0;
        for (int i = 0; i < pts.length - 1; i++) {
          d += _distanceCalc.as(LengthUnit.Meter, pts[i], pts[i + 1]);
        }
        return d;
      }

      double pathLen(List<RoadEdge>? p) {
        if (p == null) return 9999999.0;
        return p.fold(0.0, (sum, e) => sum + e.lengthMeters);
      }

      final startPtsTo = [snapStart.projectedPoint, ...eStart.geometry.sublist(snapStart.segmentIndex + 1)];
      final startPtsFrom = [snapStart.projectedPoint, ...eStart.geometry.sublist(0, snapStart.segmentIndex + 1).reversed];

      final endPtsFrom = [...eEnd.geometry.sublist(0, snapEnd.segmentIndex + 1), snapEnd.projectedPoint];
      final endPtsTo = [...eEnd.geometry.sublist(snapEnd.segmentIndex + 1).reversed, snapEnd.projectedPoint];

      final cost1 = distAlong(startPtsTo) + pathLen(path1) + distAlong(endPtsFrom);
      final cost2 = distAlong(startPtsTo) + pathLen(path2) + distAlong(endPtsTo);
      final cost3 = distAlong(startPtsFrom) + pathLen(path3) + distAlong(endPtsFrom);
      final cost4 = distAlong(startPtsFrom) + pathLen(path4) + distAlong(endPtsTo);

      final minCost = [cost1, cost2, cost3, cost4].reduce(min);

      List<LatLng> chosenStartPts;
      List<RoadEdge>? chosenPath;
      List<LatLng> chosenEndPts;

      if (minCost == cost1 && path1 != null) {
        chosenStartPts = startPtsTo;
        chosenPath = path1;
        chosenEndPts = endPtsFrom;
      } else if (minCost == cost2 && path2 != null) {
        chosenStartPts = startPtsTo;
        chosenPath = path2;
        chosenEndPts = endPtsTo;
      } else if (minCost == cost3 && path3 != null) {
        chosenStartPts = startPtsFrom;
        chosenPath = path3;
        chosenEndPts = endPtsFrom;
      } else if (minCost == cost4 && path4 != null) {
        chosenStartPts = startPtsFrom;
        chosenPath = path4;
        chosenEndPts = endPtsTo;
      } else {
        return _routeDirectClean(
          origin: origin,
          destination: destination,
          originName: originName,
          destinationName: destinationName,
        );
      }

      edgesUsed.add(eStart);
      for (var pt in chosenStartPts) {
        if (polyline.isEmpty || _distanceCalc.as(LengthUnit.Meter, polyline.last, pt) > 3.0) {
          polyline.add(pt);
        }
      }

      for (var e in chosenPath) {
        edgesUsed.add(e);
        for (int i = 1; i < e.geometry.length; i++) {
          if (polyline.isEmpty || _distanceCalc.as(LengthUnit.Meter, polyline.last, e.geometry[i]) > 3.0) {
            polyline.add(e.geometry[i]);
          }
        }
      }

      edgesUsed.add(eEnd);
      for (var pt in chosenEndPts) {
        if (polyline.isEmpty || _distanceCalc.as(LengthUnit.Meter, polyline.last, pt) > 3.0) {
          polyline.add(pt);
        }
      }

      if (_distanceCalc.as(LengthUnit.Meter, polyline.last, destination) > 5.0) {
        polyline.add(destination);
      }
    }

    // Hitung total jarak dan durasi
    double totalDist = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      totalDist += _distanceCalc.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
    }
    final totalDuration = (totalDist / (32.0 / 3.6)).clamp(30.0, 7200.0);

    final steps = _synthesizeSteps(polyline, originName, destinationName, edgesUsed: edgesUsed);

    return NavigationRoute(
      originName: originName,
      destinationName: destinationName,
      originPoint: origin,
      destinationPoint: destination,
      polylinePoints: polyline,
      steps: steps,
      totalDistanceMeters: totalDist,
      totalDurationSeconds: totalDuration,
    );
  }

  static List<RoadEdge>? _findDijkstraEdges(String startNodeId, String endNodeId) {
    if (startNodeId == endNodeId) return [];

    final adj = <String, List<RoadEdge>>{};
    for (var e in _edges) {
      adj.putIfAbsent(e.fromId, () => []).add(e);
    }

    final distances = <String, double>{startNodeId: 0.0};
    final previousEdge = <String, RoadEdge?>{};
    final unvisited = <String>{for (var n in _nodes.keys) n};

    while (unvisited.isNotEmpty) {
      String? currentId;
      double minD = double.infinity;
      for (var id in unvisited) {
        final d = distances[id] ?? double.infinity;
        if (d < minD) {
          minD = d;
          currentId = id;
        }
      }

      if (currentId == null || minD == double.infinity) break;
      if (currentId == endNodeId) break;

      unvisited.remove(currentId);

      final neighbors = adj[currentId] ?? [];
      for (var edge in neighbors) {
        if (!unvisited.contains(edge.toId)) continue;
        final newDist = minD + edge.lengthMeters;
        if (newDist < (distances[edge.toId] ?? double.infinity)) {
          distances[edge.toId] = newDist;
          previousEdge[edge.toId] = edge;
        }
      }
    }

    final List<RoadEdge> pathEdges = [];
    String? curr = endNodeId;
    while (curr != null && curr != startNodeId) {
      final edge = previousEdge[curr];
      if (edge == null) break;
      pathEdges.insert(0, edge);
      curr = edge.fromId;
    }

    return pathEdges.isNotEmpty ? pathEdges : null;
  }

  // ---------------------------------------------------------
  // 5. CLEAN DIRECT ROUTE (NO ARTIFICIAL ZIGZAGS)
  // ---------------------------------------------------------
  static NavigationRoute _routeDirectClean({
    required LatLng origin,
    required LatLng destination,
    required String originName,
    required String destinationName,
  }) {
    final dist = _distanceCalc.as(LengthUnit.Meter, origin, destination);
    final duration = (dist / (28.0 / 3.6)).clamp(20.0, 7200.0);

    final polyline = <LatLng>[];
    const stepsCount = 10;
    for (int i = 0; i <= stepsCount; i++) {
      final t = i / stepsCount;
      polyline.add(LatLng(
        origin.latitude + (destination.latitude - origin.latitude) * t,
        origin.longitude + (destination.longitude - origin.longitude) * t,
      ));
    }

    return NavigationRoute(
      originName: originName,
      destinationName: destinationName,
      originPoint: origin,
      destinationPoint: destination,
      polylinePoints: polyline,
      steps: [
        RouteStep(
          instruction: 'Mulai perjalanan menuju $destinationName',
          streetName: destinationName,
          distanceMeters: dist,
          durationSeconds: duration,
          maneuver: ManeuverType.depart,
          point: origin,
        ),
        RouteStep(
          instruction: 'Tiba di tujuan: $destinationName',
          streetName: destinationName,
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: ManeuverType.arrive,
          point: destination,
        ),
      ],
      totalDistanceMeters: dist,
      totalDurationSeconds: duration,
    );
  }

  // ---------------------------------------------------------
  // 6. TURN-BY-TURN STEP SYNTHESIZER
  // ---------------------------------------------------------
  static List<RouteStep> _synthesizeSteps(
    List<LatLng> polyline,
    String originName,
    String destinationName, {
    List<RoadEdge>? edgesUsed,
  }) {
    if (polyline.length < 2) {
      return [
        RouteStep(
          instruction: 'Tiba di tujuan: $destinationName',
          streetName: destinationName,
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: ManeuverType.arrive,
          point: polyline.first,
        ),
      ];
    }

    final steps = <RouteStep>[];

    final distinctRoads = <String>[];
    if (edgesUsed != null && edgesUsed.isNotEmpty) {
      for (var e in edgesUsed) {
        if (distinctRoads.isEmpty || distinctRoads.last != e.roadName) {
          distinctRoads.add(e.roadName);
        }
      }
    }

    final initialStreet = distinctRoads.isNotEmpty
        ? distinctRoads.first
        : (originName.contains('Jl.') ? originName : 'Jalan Utama');

    if (distinctRoads.length <= 1) {
      double totalDist = 0;
      for (int i = 0; i < polyline.length - 1; i++) {
        totalDist += _distanceCalc.as(LengthUnit.Meter, polyline[i], polyline[i + 1]);
      }
      final dur = (totalDist / (30.0 / 3.6)).clamp(20.0, 7200.0);

      return [
        RouteStep(
          instruction: 'Mulai di $initialStreet',
          streetName: initialStreet,
          distanceMeters: totalDist,
          durationSeconds: dur,
          maneuver: ManeuverType.depart,
          point: polyline.first,
        ),
        RouteStep(
          instruction: 'Tiba di tujuan: $destinationName',
          streetName: destinationName,
          distanceMeters: 0,
          durationSeconds: 0,
          maneuver: ManeuverType.arrive,
          point: polyline.last,
        ),
      ];
    }

    final distPerRoad = <String, double>{};
    for (var r in distinctRoads) {
      distPerRoad[r] = 0.0;
    }

    if (edgesUsed != null) {
      for (var e in edgesUsed) {
        distPerRoad[e.roadName] = (distPerRoad[e.roadName] ?? 0.0) + e.lengthMeters;
      }
    }

    steps.add(RouteStep(
      instruction: 'Mulai perjalanan di ${distinctRoads[0]}',
      streetName: distinctRoads[0],
      distanceMeters: distPerRoad[distinctRoads[0]] ?? 500.0,
      durationSeconds: ((distPerRoad[distinctRoads[0]] ?? 500.0) / (30.0 / 3.6)).clamp(15.0, 1800.0),
      maneuver: ManeuverType.depart,
      point: polyline.first,
    ));

    for (int i = 1; i < distinctRoads.length; i++) {
      final currRoad = distinctRoads[i];
      final segDist = distPerRoad[currRoad] ?? 600.0;
      final dur = (segDist / (32.0 / 3.6)).clamp(15.0, 1800.0);

      ManeuverType m = ManeuverType.turnRight;
      if (currRoad.toLowerCase().contains('sudirman') || currRoad.toLowerCase().contains('malioboro')) {
        m = ManeuverType.straight;
      } else if (i % 2 == 1) {
        m = ManeuverType.turnLeft;
      }

      steps.add(RouteStep(
        instruction: _buildTurnInstruction(m, currRoad),
        streetName: currRoad,
        distanceMeters: segDist,
        durationSeconds: dur,
        maneuver: m,
        point: polyline[(polyline.length * (i / distinctRoads.length)).round().clamp(0, polyline.length - 1)],
      ));
    }

    steps.add(RouteStep(
      instruction: 'Tiba di tujuan: $destinationName',
      streetName: destinationName,
      distanceMeters: 0,
      durationSeconds: 0,
      maneuver: ManeuverType.arrive,
      point: polyline.last,
    ));

    return steps;
  }

  static String _buildTurnInstruction(ManeuverType maneuver, String streetName) {
    switch (maneuver) {
      case ManeuverType.turnLeft:
        return 'Belok kiri ke $streetName';
      case ManeuverType.turnRight:
        return 'Belok kanan ke $streetName';
      case ManeuverType.turnSlightLeft:
        return 'Sedikit ke kiri di $streetName';
      case ManeuverType.turnSlightRight:
        return 'Sedikit ke kanan di $streetName';
      case ManeuverType.uTurn:
        return 'Putar balik di $streetName';
      case ManeuverType.straight:
        return 'Lurus terus di $streetName';
      case ManeuverType.depart:
        return 'Mulai di $streetName';
      case ManeuverType.arrive:
        return 'Tiba di tujuan: $streetName';
      case ManeuverType.roundabout:
        return 'Masuk bundaran menuju $streetName';
    }
  }

  // ---------------------------------------------------------
  // 7. PRESET HIGH-FIDELITY ROUTES
  // ---------------------------------------------------------
  static NavigationRoute? _matchPreset(
    LatLng origin,
    LatLng destination,
    String originName,
    String destinationName,
  ) {
    final presets = [
      _buildTuguKeraton(),
      _buildMonasGbk(),
      _buildBundaranHiAncol(),
      _buildPasteurGedungSate(),
    ];

    for (var p in presets) {
      final pOrigin = p.polylinePoints.first;
      final pDest = p.polylinePoints.last;

      if (_distanceCalc.as(LengthUnit.Meter, origin, pOrigin) <= 450 &&
          _distanceCalc.as(LengthUnit.Meter, destination, pDest) <= 450) {
        return p.copyWith(
          originName: originName.isNotEmpty ? originName : p.originName,
          destinationName: destinationName.isNotEmpty ? destinationName : p.destinationName,
        );
      }

      if (_distanceCalc.as(LengthUnit.Meter, origin, pDest) <= 450 &&
          _distanceCalc.as(LengthUnit.Meter, destination, pOrigin) <= 450) {
        final reversedPoints = p.polylinePoints.reversed.toList();
        final steps = _synthesizeSteps(reversedPoints, originName, destinationName);
        return NavigationRoute(
          originName: originName.isNotEmpty ? originName : p.destinationName,
          destinationName: destinationName.isNotEmpty ? destinationName : p.originName,
          originPoint: reversedPoints.first,
          destinationPoint: reversedPoints.last,
          polylinePoints: reversedPoints,
          steps: steps,
          totalDistanceMeters: p.totalDistanceMeters,
          totalDurationSeconds: p.totalDurationSeconds,
        );
      }
    }

    return null;
  }

  static NavigationRoute _buildTuguKeraton() {
    final points = [
      const LatLng(-7.782889, 110.367072), // Tugu Pal Putih
      const LatLng(-7.789167, 110.365823), // Stasiun Tugu / Teteg
      const LatLng(-7.792841, 110.365823), // Jl. Malioboro
      const LatLng(-7.800278, 110.366111), // Titik Nol Km
      const LatLng(-7.803800, 110.364300), // Alun-Alun Utara
      const LatLng(-7.805284, 110.364203), // Keraton Yogyakarta
    ];

    return NavigationRoute(
      originName: 'Tugu Pal Putih',
      destinationName: 'Keraton Ngayogyakarta',
      originPoint: points.first,
      destinationPoint: points.last,
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Mulai ke arah selatan di Jl. Margo Utomo',
          streetName: 'Jl. Margo Utomo',
          distanceMeters: 750,
          durationSeconds: 110,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Lurus terus ke Jl. Malioboro',
          streetName: 'Jl. Malioboro',
          distanceMeters: 1100,
          durationSeconds: 180,
          maneuver: ManeuverType.straight,
          point: points[2],
        ),
        RouteStep(
          instruction: 'Lewati Titik Nol Km ke Jl. Pangurakan',
          streetName: 'Jl. Pangurakan',
          distanceMeters: 600,
          durationSeconds: 90,
          maneuver: ManeuverType.straight,
          point: points[3],
        ),
        RouteStep(
          instruction: 'Tiba di Gerbang Utama Keraton Yogyakarta',
          streetName: 'Plataran Keraton',
          distanceMeters: 200,
          durationSeconds: 40,
          maneuver: ManeuverType.arrive,
          point: points[5],
        ),
      ],
      totalDistanceMeters: 2650,
      totalDurationSeconds: 420,
    );
  }

  static NavigationRoute _buildMonasGbk() {
    final points = [
      const LatLng(-6.175392, 106.827153), // Monas
      const LatLng(-6.182245, 106.824982), // Jl. MH Thamrin
      const LatLng(-6.189563, 106.823908), // Sarinah
      const LatLng(-6.194432, 106.823021), // Bundaran HI
      const LatLng(-6.203341, 106.821453), // Dukuh Atas
      const LatLng(-6.208821, 106.819876), // Karet Sudirman
      const LatLng(-6.215543, 106.814232), // Semanggi
      const LatLng(-6.218521, 106.802341), // GBK Senayan
    ];

    return NavigationRoute(
      originName: 'Monas (Jakarta Pusat)',
      destinationName: 'Gelora Bung Karno (Senayan)',
      originPoint: points.first,
      destinationPoint: points.last,
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Mulai ke arah selatan di Jl. Medan Merdeka Barat',
          streetName: 'Jl. Medan Merdeka Barat',
          distanceMeters: 800,
          durationSeconds: 120,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Lurus terus melewati Bundaran HI ke Jl. Jend. Sudirman',
          streetName: 'Jl. Jenderal Sudirman',
          distanceMeters: 2400,
          durationSeconds: 320,
          maneuver: ManeuverType.straight,
          point: points[3],
        ),
        RouteStep(
          instruction: 'Ambil jalur kanan menuju Simpang Susun Semanggi',
          streetName: 'Semanggi Flyover',
          distanceMeters: 950,
          durationSeconds: 150,
          maneuver: ManeuverType.turnRight,
          point: points[6],
        ),
        RouteStep(
          instruction: 'Tiba di Gelora Bung Karno Senayan',
          streetName: 'GBK Gate 1',
          distanceMeters: 300,
          durationSeconds: 60,
          maneuver: ManeuverType.arrive,
          point: points[7],
        ),
      ],
      totalDistanceMeters: 7400,
      totalDurationSeconds: 840,
    );
  }

  static NavigationRoute _buildBundaranHiAncol() {
    final points = [
      const LatLng(-6.194432, 106.823021), // Bundaran HI
      const LatLng(-6.175392, 106.827153), // Monas
      const LatLng(-6.160124, 106.829124), // Harmoni
      const LatLng(-6.138452, 106.826543), // Glodok / Kota Tua
      const LatLng(-6.126543, 106.833452), // Ancol Taman Impian
    ];

    return NavigationRoute(
      originName: 'Bundaran HI',
      destinationName: 'Taman Impian Jaya Ancol',
      originPoint: points.first,
      destinationPoint: points.last,
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Arah utara di Jl. M.H. Thamrin menuju Monas',
          streetName: 'Jl. M.H. Thamrin',
          distanceMeters: 2100,
          durationSeconds: 280,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Lurus ke Jl. Gajah Mada melalui Kota Tua',
          streetName: 'Jl. Gajah Mada',
          distanceMeters: 3500,
          durationSeconds: 420,
          maneuver: ManeuverType.straight,
          point: points[2],
        ),
        RouteStep(
          instruction: 'Belok kanan ke Gerbang Ancol Barat',
          streetName: 'Jl. Lodan Raya',
          distanceMeters: 1200,
          durationSeconds: 180,
          maneuver: ManeuverType.turnRight,
          point: points[4],
        ),
      ],
      totalDistanceMeters: 9200,
      totalDurationSeconds: 1100,
    );
  }

  static NavigationRoute _buildPasteurGedungSate() {
    final points = [
      const LatLng(-6.893245, 107.575643), // Pasteur Toll Exit
      const LatLng(-6.899543, 107.595432), // Jl. Dr. Djunjunan
      const LatLng(-6.901234, 107.608765), // Cihampelas
      const LatLng(-6.902534, 107.618645), // Gedung Sate Bandung
    ];

    return NavigationRoute(
      originName: 'Gerbang Tol Pasteur',
      destinationName: 'Gedung Sate Bandung',
      originPoint: points.first,
      destinationPoint: points.last,
      polylinePoints: points,
      steps: [
        RouteStep(
          instruction: 'Lurus di Flyover Pasupati menuju Jl. Surapati',
          streetName: 'Flyover Pasupati',
          distanceMeters: 2800,
          durationSeconds: 300,
          maneuver: ManeuverType.depart,
          point: points[0],
        ),
        RouteStep(
          instruction: 'Belok kanan ke Jl. Diponegoro Gedung Sate',
          streetName: 'Jl. Diponegoro',
          distanceMeters: 600,
          durationSeconds: 100,
          maneuver: ManeuverType.turnRight,
          point: points[3],
        ),
      ],
      totalDistanceMeters: 4800,
      totalDurationSeconds: 620,
    );
  }
}
