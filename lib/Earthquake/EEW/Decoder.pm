package Earthquake::EEW::Decoder;

use utf8;
use vars qw($VERSION);
our $VERSION = '0.05';

#電文種別
my %code_type = (
    '35' => '最大予測震度のみ',
    '36' => 'Ｍ、最大予測震度及び主要動到達予測時刻',
    '37' =>
        'Ｍ、最大予測度及び主要動到達予測時刻（確度大）',
    '39' => 'キャンセル報',
    '47' => '一般向け速報',
    '48' => 'キャンセル報',
);

#発信官署
my %section = (
    '01' => '札幌',
    '02' => '仙台',
    '03' => '東京',
    '04' => '大阪',
    '05' => '福岡',
    '06' => '沖縄',
);

#訓練等の識別符
my %msg_type = (
    '00' => '通常',
    '01' => '訓練',
    '10' => '取り消し',
    '11' => '訓練取り消し',
    '20' => '参考/テスト',
    '30' => 'コードのみ配信試験',
);

#震度
my %shindo = (
    '01' => '震度1',
    '02' => '震度2',
    '03' => '震度3',
    '04' => '震度4',
    '5-' => '震度5弱',
    '5+' => '震度5強',
    '6-' => '震度6弱',
    '6+' => '震度6強',
    '07' => '震度7',
    '//' => '不明',
);

#データの確からしさ
my %rk1 = (
    '1' =>
        'P 波／S 波レベル越え、またはテリトリー法（１点）',
    '2' => 'テリトリー法（2 点）',
    '3' => 'グリッドサーチ法（3 点／4 点）',
    '4' => 'グリッドサーチ法（5 点）',
    '5' =>
        '防災科研システム（4 点以下、または精度情報なし）',
    '6' => '防災科研システム（5 点以上）',
    '7' => 'EPOS（海域〔観測網外〕）',
    '8' => 'EPOS（内陸〔観測網内〕）',
    '9' => '予備',
    '/' => '不明、未設定時、キャンセル時',
);

#震源の深さの確からしさ
my %rk2 = (
    '1' =>
        'P 波／S 波レベル越え、またはテリトリー法（1 点）',
    '2' => 'テリトリー法（2 点）',
    '3' => 'グリッドサーチ法（3 点／4 点）',
    '4' => 'グリッドサーチ法（5 点）',
    '5' =>
        '防災科研システム（4 点以下、または精度情報なし）',
    '6'  => '防災科研システム（5 点以上）',
    '7'  => 'EPOS（海域〔観測網外〕）',
    '8'  => 'EPOS（内陸〔観測網内〕）',
    '9'  => '予備',
    '/ ' => '不明、未設定時、キャンセル時',
);

#マグニチュードの確からしさ
my %rk3 = (
    '1' => '未定義',
    '2' => '防災科研システム',
    '3' => '全点（最大5 点）P 相',
    '4' => 'P 相／全相混在',
    '5' => '全点（最大5 点）全相',
    '6' => 'EPOS',
    '7' => '未定義',
    '8' => 'P 波／S 波レベル越え',
    '9' => '予備',
    '/' => '不明、未設定時、キャンセル時',

);

#地震の発生場所
my %rt1 = (
    '0' => '陸',
    '1' => '海',
    '/' => '不明',
);

#最大予測震度の変化
my %rc1 = (
    '0' => 'ほとんど変化なし',
    '1' => '最大予測震度が1.0 以上大きくなった。',
    '2' => '最大予測震度が1.0 以上小さくなった。',
    '/' => '不明、未設定時、キャンセル時',
);

#最大予測震度の変化の理由
my %rc2 = (
    '0' => '変化なし',
    '1' => '主としてＭが変化したため(1.0 以上)。',
    '2' => '主として震源位置が変化したため(10km 以上)。',
    '3' =>
        'Ｍ及び震源位置が変化したため(1 と2 の複合条件)。',
    '4' =>
        '震源の深さが変化したため(上記のいずれにもあてはまらず、30km 以上の変化)。',
    '/' => '不明、未設定時、キャンセル時',
);

#到達判定
my %ebiyy = (
    '00' => '未到達',
    '01' => '既に到達と予想',
    '11' => '未定義',
    '//' => '不明',
);

#発表情報種別
my %warn_type = (
    'NCN'  => '高度利用者向け',
    'NPN'  => '一般向け',
    'NCPN' => '一般向け',
    'PRC'  => '強い揺れが推定される地域の追加',
    'EBI'  => '予想震度と到達時間',
    'CAI'  => '新たに追加された強い揺れが推定される地方',
    'CPI'  => '新たに追加された強い揺れが推定される県',
    'CBI'  => '新たに追加された強い揺れが推定される地域',
    'PAI'  => '強い揺れが推定される地方',
    'PPI'  => '強い揺れが推定される県',
    'PBI'  => '強い揺れが推定される地域',
);

#発表情報状況種別
my %warn_state = (
    '0' => '通常発表',
    '6' => '情報内容訂正',
    '7' => 'キャンセルを誤った場合の訂正',
    '8' => '訂正事項を盛り込んだ最終の高度利用者向け緊急地震速報',
    '9' => '最終の高度利用者向け緊急地震速報',
    '/' => '未設定'
);

#震央コード(一般向け)
my %ippan_shinou_code = (
    '0000' => '',
    '9011' => '北海道道央',
    '9012' => '北海道道南',
    '9013' => '北海道道北',
    '9014' => '北海道道東',
    '9014' => '北海道道東',
    '9700' => '北海道南西沖',
    '9701' => '北海道西方沖',
    '9702' => '石狩湾',
    '9703' => '北海道北西沖',
    '9704' => '宗谷海峡',
    '9705' => '国後島付近',
    '9706' => '択捉島付近',
    '9707' => '北海道東方沖',
    '9708' => '根室半島沖',
    '9709' => '釧路沖',
    '9710' => '十勝沖',
    '9711' => '浦河沖',
    '9712' => '苫小牧沖',
    '9713' => '内浦湾',
    '9714' => '宗谷東方沖',
    '9715' => '網走沖',
    '9716' => '択捉島南東沖',
    '9020' => '青森県',
    '9030' => '岩手県',
    '9040' => '宮城県',
    '9050' => '秋田県',
    '9050' => '秋田県',
    '9060' => '山形県',
    '9207' => '福島県',
    '9730' => '津軽海峡',
    '9731' => '山形沖',
    '9732' => '秋田沖',
    '9733' => '青森西方沖',
    '9734' => '陸奥湾',
    '9735' => '青森東方沖',
    '9736' => '岩手沖',
    '9737' => '宮城沖',
    '9738' => '三陸沖',
    '9739' => '福島沖',
    '9080' => '茨城県',
    '9760' => '千葉南東沖',
    '9090' => '栃木県',
    '9100' => '群馬県',
    '9110' => '埼玉県',
    '9120' => '千葉県',
    '9761' => '千葉南方沖',
    '9130' => '東京',
    '9130' => '東京',
    '9140' => '神奈川県',
    '9150' => '新潟県',
    '9372' => '新潟沖',
    '9160' => '富山県',
    '9170' => '石川県',
    '9180' => '福井県',
    '9190' => '山梨県',
    '9200' => '長野県',
    '9210' => '岐阜県',
    '9220' => '静岡県',
    '9230' => '愛知県',
    '9240' => '三重県',
    '9762' => '三重南東沖',
    '9763' => '茨城沖',
    '9764' => '関東東方沖',
    '9765' => '千葉東方沖',
    '9766' => '関東南方沖',
    '9767' => '伊豆諸島近海',
    '9768' => '東京湾',
    '9769' => '相模湾',
    '9770' => '伊豆東方沖',
    '9771' => '静岡沖(※3)',
    '9772' => '三河湾',
    '9773' => '伊勢湾',
    '9774' => '若狭湾',
    '9775' => '福井沖',
    '9776' => '石川西方沖',
    '9777' => '能登半島沖',
    '9778' => '富山湾',
    '9779' => '佐渡付近',
    '9780' => '東海道沖',
    '9250' => '滋賀県',
    '9260' => '京都府',
    '9270' => '大阪府',
    '9280' => '兵庫県',
    '9290' => '奈良県',
    '9300' => '和歌山県',
    '9310' => '鳥取県',
    '9310' => '鳥取県',
    '9320' => '島根県',
    '9330' => '岡山県',
    '9340' => '広島県',
    '9360' => '徳島県',
    '9370' => '香川県',
    '9380' => '愛媛県',
    '9390' => '高知県',
    '9790' => '土佐湾',
    '9791' => '紀伊水道',
    '9792' => '大阪湾',
    '9793' => '播磨灘',
    '9794' => '瀬戸内海',
    '9795' => '安芸灘',
    '9796' => '周防灘',
    '9797' => '伊予灘',
    '9798' => '豊後水道',
    '9799' => '山口北西沖',
    '9800' => '島根沖',
    '9801' => '鳥取沖',
    '9802' => '隠岐島近海',
    '9803' => '兵庫北方沖',
    '9804' => '京都沖',
    '9805' => '淡路島付近',
    '9806' => '和歌山沖',
    '9350' => '山口県',
    '9400' => '福岡県',
    '9410' => '佐賀県',
    '9420' => '長崎県',
    '9430' => '熊本県',
    '9440' => '大分県',
    '9450' => '宮崎県',
    '9460' => '鹿児島県',
    '9820' => '五島列島近海',
    '9821' => '天草灘',
    '9822' => '有明海',
    '9823' => '橘湾',
    '9824' => '鹿児島湾',
    '9825' => '種子島近海',
    '9826' => '日向灘',
    '9827' => '奄美大島近海',
    '9828' => '対馬近海',
    '9829' => '福岡北西沖',
    '9830' => '鹿児島西方沖',
    '9831' => '薩南諸島近海',
    '9832' => '鹿児島東方沖(※４)',
    '9833' => '九州南東沖',
    '9471' => '沖縄本島近海',
    '9472' => '南大東島近海',
    '9850' => '沖縄南方沖',
    '9473' => '宮古島近海',
    '9851' => '石垣島近海',
    '9852' => '石垣島南方沖',
    '9853' => '西表島付近',
    '9854' => '与那国島近海',
    '9855' => '宮古島北西沖',
    '9856' => '石垣島北西沖',
    '9900' => '台湾付近',
    '9901' => '東シナ海',
    '9902' => '四国沖',
    '9903' => '鳥島近海',
    '9904' => '鳥島東方沖',
    '9905' => 'オホーツク海',
    '9906' => 'サハリン付近',
    '9907' => '日本海北部',
    '9908' => '日本海中部',
    '9909' => '日本海西部',
    '9781' => '父島近海',
    '9781' => '父島近海',
    '9910' => '南海道南方沖',
    '9911' => 'サハリン南部',
    '9912' => '朝鮮半島南部'
);

#震央コード
my %shinou_code = (
    '000' => '',
    100   => '石狩支庁北部',
    101   => '石狩支庁中部',
    102   => '石狩支庁南部',
    105   => '渡島支庁北部',
    106   => '渡島支庁東部',
    107   => '渡島支庁西部',
    110   => '檜山支庁',
    115   => '後志支庁北部',
    116   => '後志支庁東部',
    117   => '後志支庁西部',
    120   => '空知支庁北部',
    121   => '空知支庁中部',
    122   => '空知支庁南部',
    125   => '上川支庁北部',
    126   => '上川支庁中部',
    127   => '上川支庁南部',
    130   => '留萌支庁中北部',
    131   => '留萌支庁南部',
    135   => '宗谷支庁北部',
    136   => '宗谷支庁南部',
    140   => '網走支庁網走地方',
    141   => '網走支庁北見地方',
    142   => '網走支庁紋別地方',
    145   => '胆振支庁西部',
    146   => '胆振支庁中東部',
    150   => '日高支庁西部',
    151   => '日高支庁中部',
    152   => '日高支庁東部',
    155   => '十勝支庁北部',
    156   => '十勝支庁中部',
    157   => '十勝支庁南部',
    160   => '釧路支庁北部',
    161   => '釧路支庁中南部',
    165   => '根室支庁北部',
    166   => '根室支庁中部',
    167   => '根室支庁南部',
    180   => '北海道南西沖',
    181   => '北海道西方沖',
    182   => '石狩湾',
    183   => '北海道北西沖',
    184   => '宗谷海峡',
    186   => '国後島付近',
    187   => '択捉島付近',
    188   => '北海道東方沖',
    189   => '根室半島南東沖',
    190   => '釧路沖',
    191   => '十勝沖',
    192   => '浦河沖',
    193   => '苫小牧沖',
    194   => '内浦湾',
    195   => '宗谷東方沖',
    196   => '網走沖',
    197   => '択捉島南東沖',
    200   => '青森県津軽北部',
    201   => '青森県津軽南部',
    202   => '青森県三八上北地方',
    203   => '青森県下北地方',
    210   => '岩手県沿岸北部',
    211   => '岩手県沿岸南部',
    212   => '岩手県内陸北部',
    213   => '岩手県内陸南部',
    220   => '宮城県北部',
    221   => '宮城県南部',
    222   => '宮城県中部',
    230   => '秋田県沿岸北部',
    231   => '秋田県沿岸南部',
    232   => '秋田県内陸北部',
    233   => '秋田県内陸南部',
    240   => '山形県庄内地方',
    241   => '山形県最上地方',
    242   => '山形県村山地方',
    243   => '山形県置賜地方',
    250   => '福島県中通り',
    251   => '福島県浜通り',
    252   => '福島県会津',
    280   => '津軽海峡',
    281   => '山形県沖',
    282   => '秋田県沖',
    283   => '青森県西方沖',
    284   => '陸奥湾',
    285   => '青森県東方沖',
    286   => '岩手県沖',
    287   => '宮城県沖',
    288   => '三陸沖',
    289   => '福島県沖',
    300   => '茨城県北部',
    301   => '茨城県南部',
    309   => '千葉県南東沖',
    310   => '栃木県北部',
    311   => '栃木県南部',
    320   => '群馬県北部',
    321   => '群馬県南部',
    330   => '埼玉県北部',
    331   => '埼玉県南部',
    332   => '埼玉県秩父地方',
    340   => '千葉県北東部',
    341   => '千葉県北西部',
    342   => '千葉県南部',
    349   => '房総半島南方沖',
    350   => '東京都２３区',
    351   => '東京都多摩東部',
    352   => '東京都多摩西部',
    360   => '神奈川県東部',
    361   => '神奈川県西部',
    370   => '新潟県上越地方',
    371   => '新潟県中越地方',
    372   => '新潟県下越地方',
    375   => '新潟県佐渡地方',
    378   => '新潟県下越沖',
    379   => '新潟県上中越沖',
    380   => '富山県東部',
    381   => '富山県西部',
    390   => '石川県能登地方',
    391   => '石川県加賀地方',
    400   => '福井県嶺北',
    401   => '福井県嶺南',
    411   => '山梨県中・西部',
    412   => '山梨県東部・富士五湖',
    420   => '長野県北部',
    421   => '長野県中部',
    422   => '長野県南部',
    430   => '岐阜県飛騨地方',
    431   => '岐阜県美濃東部',
    432   => '岐阜県美濃中西部',
    440   => '静岡県伊豆地方',
    441   => '静岡県東部',
    442   => '静岡県中部',
    443   => '静岡県西部',
    450   => '愛知県東部',
    451   => '愛知県西部',
    460   => '三重県北部',
    461   => '三重県中部',
    462   => '三重県南部',
    469   => '三重県南東沖',
    471   => '茨城県沖',
    472   => '関東東方沖',
    473   => '千葉県東方沖',
    475   => '八丈島東方沖',
    476   => '八丈島近海',
    477   => '東京湾',
    478   => '相模湾',
    480   => '伊豆大島近海',
    481   => '伊豆半島東方沖',
    482   => '三宅島近海',
    483   => '新島・神津島近海',
    485   => '駿河湾',
    486   => '駿河湾南方沖',
    487   => '遠州灘',
    489   => '三河湾',
    490   => '伊勢湾',
    492   => '若狭湾',
    493   => '福井県沖',
    494   => '石川県西方沖',
    495   => '能登半島沖',
    497   => '富山湾',
    498   => '佐渡付近',
    499   => '東海道南方沖',
    500   => '滋賀県北部',
    501   => '滋賀県南部',
    510   => '京都府北部',
    511   => '京都府南部',
    520   => '大阪府北部',
    521   => '大阪府南部',
    530   => '兵庫県北部',
    531   => '兵庫県南東部',
    532   => '兵庫県南西部',
    540   => '奈良県',
    550   => '和歌山県北部',
    551   => '和歌山県南部',
    560   => '鳥取県東部',
    562   => '鳥取県中部',
    563   => '鳥取県西部',
    570   => '島根県東部',
    571   => '島根県西部',
    580   => '岡山県北部',
    581   => '岡山県南部',
    590   => '広島県北部',
    591   => '広島県南東部',
    592   => '広島県南西部',
    600   => '徳島県北部',
    601   => '徳島県南部',
    610   => '香川県東部',
    611   => '香川県西部',
    620   => '愛媛県東予',
    621   => '愛媛県中予',
    622   => '愛媛県南予',
    630   => '高知県東部',
    631   => '高知県中部',
    632   => '高知県西部',
    673   => '土佐湾',
    674   => '紀伊水道',
    675   => '大阪湾',
    676   => '播磨灘',
    677   => '瀬戸内海中部',
    678   => '安芸灘',
    679   => '周防灘',
    680   => '伊予灘',
    681   => '豊後水道',
    682   => '山口県北西沖',
    683   => '島根県沖',
    684   => '鳥取県沖',
    685   => '隠岐島近海',
    686   => '兵庫県北方沖',
    687   => '京都府沖',
    688   => '淡路島付近',
    689   => '和歌山県南方沖',
    700   => '山口県北部',
    701   => '山口県東部',
    702   => '山口県西部',
    710   => '福岡県福岡地方',
    711   => '福岡県北九州地方',
    712   => '福岡県筑豊地方',
    713   => '福岡県筑後地方',
    720   => '佐賀県北部',
    721   => '佐賀県南部',
    730   => '長崎県北部',
    731   => '長崎県南西部',
    732   => '長崎県島原半島',
    740   => '熊本県阿蘇地方',
    741   => '熊本県熊本地方',
    742   => '熊本県球磨地方',
    743   => '熊本県天草・芦北地方',
    750   => '大分県北部',
    751   => '大分県中部',
    752   => '大分県南部',
    753   => '大分県西部',
    760   => '宮崎県北部平野部',
    761   => '宮崎県北部山沿い',
    762   => '宮崎県南部平野部',
    763   => '宮崎県南部山沿い',
    770   => '鹿児島県薩摩地方',
    771   => '鹿児島県大隅地方',
    783   => '五島列島近海',
    784   => '天草灘',
    785   => '有明海',
    786   => '橘湾',
    787   => '鹿児島湾',
    790   => '種子島近海',
    791   => '日向灘',
    793   => '奄美大島近海',
    795   => '壱岐・対馬近海',
    796   => '福岡県北西沖',
    797   => '薩摩半島西方沖',
    798   => 'トカラ列島近海',
    799   => '奄美大島北西沖',
    820   => '大隅半島東方沖',
    821   => '九州地方南東沖',
    822   => '種子島南東沖',
    823   => '奄美大島北東沖',
    850   => '沖縄本島近海',
    851   => '南大東島近海',
    852   => '沖縄本島南方沖',
    853   => '宮古島近海',
    854   => '石垣島近海',
    855   => '石垣島南方沖',
    856   => '西表島付近',
    857   => '与那国島近海',
    858   => '沖縄本島北西沖',
    859   => '宮古島北西沖',
    860   => '石垣島北西沖',
    900   => '台湾付近',
    901   => '東シナ海',
    902   => '四国沖',
    903   => '鳥島近海',
    904   => '鳥島東方沖',
    905   => 'オホーツク海南部',
    906   => 'サハリン西方沖',
    907   => '日本海北部',
    908   => '日本海中部',
    909   => '日本海西部',
    911   => '父島近海',
    912   => '千島列島',
    913   => '千島列島南東沖',
    914   => '北海道南東沖',
    915   => '東北地方東方沖',
    916   => '小笠原諸島西方沖',
    917   => '硫黄島近海',
    918   => '小笠原諸島東方沖',
    919   => '南海道南方沖',
    920   => '薩南諸島東方沖',
    921   => '本州南方沖',
    922   => 'サハリン南部付近',
    930   => '北西太平洋',
    932   => 'マリアナ諸島',
    933   => '黄海',
    934   => '朝鮮半島南部',
    935   => '朝鮮半島北部',
    936   => '中国東北部',
    937   => 'ウラジオストク付近',
    938   => 'シベリア南部',
    939   => 'サハリン近海',
    940   => 'アリューシャン列島',
    941   => 'カムチャツカ半島付近',
    942   => '北米西部',
    943   => '北米中部',
    944   => '北米東部',
    945   => '中米',
    946   => '南米西部',
    947   => '南米中部',
    948   => '南米東部',
    949   => '北東太平洋',
    950   => '南太平洋',
    951   => 'インドシナ半島付近',
    952   => 'フィリピン付近',
    953   => 'インドネシア付近',
    954   => 'グアム付近',
    955   => 'ニューギニア付近',
    956   => 'ニュージーランド付近',
    957   => 'オーストラリア付近',
    958   => 'シベリア付近',
    959   => 'ロシア西部',
    960   => 'ロシア中部',
    961   => 'ロシア東部',
    962   => '中央アジア',
    963   => '中国西部',
    964   => '中国中部',
    965   => '中国東部',
    966   => 'インド付近',
    967   => 'インド洋',
    968   => '中東',
    969   => 'ヨーロッパ西部',
    970   => 'ヨーロッパ中部',
    971   => 'ヨーロッパ東部',
    972   => '地中海',
    973   => 'アフリカ西部',
    974   => 'アフリカ中部',
    975   => 'アフリカ東部',
    976   => '北大西洋',
    977   => '南大西洋',
    978   => '北極付近',
    979   => '南極付近'
);

sub new {
    my $class = shift;
    my %conf  = @_;
    $conf{basedir} = '/tmp';
    return bless {%conf}, $class;
}

#電文解析
sub read_data {
    my ( $self, $str ) = @_;
    my $data;
    my $now_code = '';
    foreach my $line ( split /[\r\n]/, $str ) {
        if ( $line =~ /(\d{2}) (\d{2}) (\d{2}) (\d{12}) C(\d{2})/ ) {
            $data->{'code_type'}    = $code_type{$1};
            $data->{'code'}    = $1;
            $data->{'section'}      = $section{$2};
            $data->{'section_code'}      = $2;
            $data->{'msg_type'}     = $msg_type{$3};
            $data->{'msg_type_code'}     = $3;
            $data->{'warn_time'}    = $4;
            $data->{'command_code'} = $5;
        $now_code='';
        }
        elsif ( $line =~ /^(\d{12})/ ) {
            $data->{'eq_time'} = $1;
        $now_code='';
        }
        elsif ( $line =~ /ND(\d{14}) NCN(\d)(\d{2})/ ) {
            $data->{'eq_id'}     = $1;
            $data->{'warn_type'} = $warn_type{'NCN'};
            $data->{'warn_code'} = 'NCN';
            $data->{'warn_state'} = $warn_state{$2};
            $data->{'warn_state_code'} = $2;
            $data->{'warn_num_str'} = $3;
            $data->{'warn_num'}  = $3 * 1;
            
        $now_code='';
        }
        elsif ( $line =~ /([0-9\/]{3}) [NS](\d{3}) [EW](\d{4}) ([0-9\/]{3}) ([0-9\/]{2}) ([0-9\-\+\/]{2}) RK.+/ )
        {
            $data->{'center_code'}  = $1;
            $data->{'center_name'}  = $shinou_code{$1};
            $data->{'center_lat'}   = $2 / 10;
            $data->{'center_lng'}   = $3 / 10;
            $data->{'center_depth'} = $4 * 1;
            $data->{'magnitude'}    = $5 / 10;
            $data->{'shindo'}       = $shindo{$6};
            $data->{'shindo_code'}  = $6;
        $now_code='';
        }
        elsif ( $line =~ /([0-9\/]{4}) [NS](\d{3}) [EW](\d{4}) ([0-9\/]{3})/ ) {
            $data->{'center_code'}  = $1;
            $data->{'center_name'}  = $ippan_shinou_code{$1};
            $data->{'center_lat'}   = $2 / 10;
            $data->{'center_lng'}   = $3 / 10;
            $data->{'center_depth'} = $4 * 1;
        $now_code='';
        }
        elsif ( $line =~ /([CP][APB]I) ([0-9\s]+)/ ) {
        $now_code=$1;
            foreach my $code ( split / /, $2 ) {
                $data->{$now_code}->{$code}->{'name'} = $ippan_shinou_code{$code};
            }
        }
        elsif ( $line  =~ /(EBI |^)(\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2}) (\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2}) (\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2})/ )
        {
        $now_code='EBI';

            $data->{'EBI'}->{$2}->{'name'}    = $shinou_code{$2};
            $data->{'EBI'}->{$2}->{'shindo1'} = $shindo{$3};
            $data->{'EBI'}->{$2}->{'shindo1_code'} = $3;
            $data->{'EBI'}->{$2}->{'shindo2'} = $shindo{$4};
            $data->{'EBI'}->{$2}->{'shindo2_code'} = $4;
            $data->{'EBI'}->{$2}->{'time'}    = $5;
            $data->{'EBI'}->{$2}->{'arrive'}  = $ebiyy{$6};
            $data->{'EBI'}->{$2}->{'arrive_code'}  = $6;

            $data->{'EBI'}->{$7}->{'name'}    = $shinou_code{$7};
            $data->{'EBI'}->{$7}->{'shindo1'} = $shindo{$8};
            $data->{'EBI'}->{$7}->{'shindo1_code'} = $8;
            $data->{'EBI'}->{$7}->{'shindo2'} = $shindo{$9};
            $data->{'EBI'}->{$7}->{'shindo2_code'} = $9;
            $data->{'EBI'}->{$7}->{'time'}    = $10;
            $data->{'EBI'}->{$7}->{'arrive'}  = $ebiyy{$11};
            $data->{'EBI'}->{$7}->{'arrive_code'}  = $11;

            $data->{'EBI'}->{$12}->{'name'}    = $shinou_code{$12};
            $data->{'EBI'}->{$12}->{'shindo1'} = $shindo{$13};
            $data->{'EBI'}->{$12}->{'shindo1_code'} = $13;
            $data->{'EBI'}->{$12}->{'shindo2'} = $shindo{$14};
            $data->{'EBI'}->{$12}->{'shindo2_code'} = $14;
            $data->{'EBI'}->{$12}->{'time'}    = $15;
            $data->{'EBI'}->{$12}->{'arrive'}  = $ebiyy{$16};
            $data->{'EBI'}->{$12}->{'arrive_code'}  = $16;
        }
        elsif ( $line =~ /(EBI |^)(\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2}) (\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2})/ )
        {
            $now_code='EBI';

            $data->{'EBI'}->{$2}->{'name'}    = $shinou_code{$2};
            $data->{'EBI'}->{$2}->{'shindo1'} = $shindo{$3};
            $data->{'EBI'}->{$2}->{'shindo1_code'} = $3;
            $data->{'EBI'}->{$2}->{'shindo2'} = $shindo{$4};
            $data->{'EBI'}->{$2}->{'shindo2_code'} = $4;
            $data->{'EBI'}->{$2}->{'time'}    = $5;
            $data->{'EBI'}->{$2}->{'arrive'}  = $ebiyy{$6};
            $data->{'EBI'}->{$2}->{'arrive_code'}  = $6;

            $data->{'EBI'}->{$7}->{'name'}    = $shinou_code{$7};
            $data->{'EBI'}->{$7}->{'shindo1'} = $shindo{$8};
            $data->{'EBI'}->{$7}->{'shindo1_code'} = $8;
            $data->{'EBI'}->{$7}->{'shindo2'} = $shindo{$9};
            $data->{'EBI'}->{$7}->{'shindo2_code'} = $9;
            $data->{'EBI'}->{$7}->{'time'}    = $10;
            $data->{'EBI'}->{$7}->{'arrive'}  = $ebiyy{$11};
            $data->{'EBI'}->{$7}->{'arrive_code'}  = $11;
        }
        elsif ( $line =~ /(EBI |^)(\d{3}) S([0-9\-\+]{2})([0-9\-\+\/]{2}) ([\d|\/]{6}) (\d{2})/ )
        {
            $now_code='EBI';

            $data->{'EBI'}->{$2}->{'name'}    = $shinou_code{$2};
            $data->{'EBI'}->{$2}->{'shindo1'} = $shindo{$3};
            $data->{'EBI'}->{$2}->{'shindo1_code'} = $3;
            $data->{'EBI'}->{$2}->{'shindo2'} = $shindo{$4};
            $data->{'EBI'}->{$2}->{'shindo2_code'} = $4;
            $data->{'EBI'}->{$2}->{'time'}    = $5;
            $data->{'EBI'}->{$2}->{'arrive'}  = $ebiyy{$6};
            $data->{'EBI'}->{$2}->{'arrive_code'}  = $6;
        }
        elsif ($now_code && $line=~/([0-9\s]+)/){
            foreach my $code ( split / /, $1 ) {
                if($now_code =~ /[PC]BI/){
                    $data->{$now_code}->{$code}->{'name'} = $ippan_shinou_code{$code};
                } else {
                    $data->{$now_code}->{$code}->{'name'} = $shinou_code{$code};
                }
            }
        }
    }
    return $data;
}

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Earthquake::EEW::Decoder - Perl extension for JMA Earthquake Early Warning data

=head1 VERSION

Version 0.05

=head1 SYNOPSIS

  use Earthquake::EEW::Decoder;
  use Data::Dumper;
  use utf8;

  my $eew = Earthquake::EEW::Decoder->new();
  $data = <<EoF;
  37 03 00 110311144702 C11
  110311144616
  ND20110311144640 NCN009 JD////////////// JN///
  288 N381 E1429 010 76 5- RK66444 RT11/// RC0////
  EBI 222 S5-04 ////// 11 220 S5-04 ////// 11 211 S5-04 ////// 11
  210 S5-04 144703 10 221 S5-04 144703 10 213 S0404 ////// 11
  251 S0404 144704 10 250 S0404 144711 10 241 S0404 144715 10
  212 S0404 144715 10 242 S0404 144715 10 233 S0404 144715 10
  300 S0404 144721 00 252 S0404 144722 00 240 S0404 144727 00
  243 S0403 144719 00 231 S0403 144730 00 202 S0403 144732 00
  372 S0403 144732 00 301 S0403 144733 00 230 S0403 144736 00
  340 S0403 144739 00 331 S0403 144748 00
  9999=
  EoF
  my $d = $eew->read_data($data);
  print Dumper $d;

=head1 DESCRIPTION

Earthquake Early Warning(Japan)
The Earthquake Early Warning (EEW) (緊急地震速報 ,Kinkyu- Jishin Sokuho-) is a warning which is issued just after an earthquake in Japan is detected.
The warnings are issued mainly by Japan Meteorological Agency (JMA).
JMA has two EEW schemes. One is for advanced users. The other is for the general public, which is mainly mentioned in detail in this article.
Earthquake::EEW::Decoder supported 2 schemes.

=head2 EXPORT

=head1 AUTHOR

Satoshi KUBOTA, C<< <skubota at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-earthquake-eew-decoder at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Earthquake-EEW-Decoder>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Earthquake::EEW::Decoder


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Earthquake-EEW-Decoder>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Earthquake-EEW-Decoder>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Earthquake-EEW-Decoder>

=item * Search CPAN

L<http://search.cpan.org/dist/Earthquake-EEW-Decoder/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Satoshi KUBOTA.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of Earthquake::EEW::Decoder
