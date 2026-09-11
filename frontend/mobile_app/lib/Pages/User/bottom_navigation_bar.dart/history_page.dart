import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<bool> _apostleDayFuture;

  String _selectedLang = 'en';

  final Map<String, String> _supportedLanguages = {
    'English': 'en',
    'Sepedi': 'nso',
    'Tshivenda': 've',
    'Sesotho': 'st',
    'IsiXhosa': 'xh',
    'IsiZulu': 'zu',
    'Xitsonga': 'ts',
  };

  @override
  void initState() {
    super.initState();
    _apostleDayFuture = _checkApostleDay();
  }

  Future<bool> _checkApostleDay() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final responses = await Future.wait([
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/events/'),
          headers: headers,
        ),
        http.get(
          Uri.parse('${Api().BACKEND_BASE_URL_DEBUG}/event_diary/'),
          headers: headers,
        ),
      ]);

      List<dynamic> allEvents = [];

      for (var response in responses) {
        if (response.statusCode == 200) {
          final decodedData = json.decode(response.body);
          if (decodedData is Map<String, dynamic> &&
              decodedData.containsKey('results')) {
            allEvents.addAll(decodedData['results']);
          } else if (decodedData is List) {
            allEvents.addAll(decodedData);
          }
        }
      }

      Map<String, dynamic>? apostleEvent;
      for (var e in allEvents) {
        String title = (e['title'] ?? '').toString().toLowerCase().trim();
        if (title.contains('apostle day')) {
          apostleEvent = e;
          break;
        }
      }

      if (apostleEvent != null) {
        String rawDay = apostleEvent['day'].toString().toLowerCase().trim();
        String rawMonth = apostleEvent['month'].toString().toLowerCase().trim();

        RegExp numReg = RegExp(r'\d+');
        var dayMatch = numReg.firstMatch(rawDay);
        int dayInt = dayMatch != null ? int.parse(dayMatch.group(0)!) : -1;

        int monthInt = -1;
        const monthMap = {
          'jan': 1,
          'feb': 2,
          'mar': 3,
          'apr': 4,
          'may': 5,
          'jun': 6,
          'jul': 7,
          'aug': 8,
          'sep': 9,
          'oct': 10,
          'nov': 11,
          'dec': 12,
        };

        for (var key in monthMap.keys) {
          if (rawMonth.contains(key)) {
            monthInt = monthMap[key]!;
            break;
          }
        }

        DateTime now = DateTime.now();
        return now.month == monthInt && now.day == dayInt;
      }
    } catch (e) {
      debugPrint("Error fetching Apostle Day date: $e");
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      color.primaryColor.withOpacity(0.08),
      color.scaffoldBackgroundColor,
    );

    return Container(
      alignment: Alignment.topLeft,
      color: neumoBaseColor,
      child: FutureBuilder<bool>(
        future: _apostleDayFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: color.primaryColor),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Container(
                height: 65,
                margin: const EdgeInsets.only(top: 5, bottom: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _supportedLanguages.length,
                  itemBuilder: (context, index) {
                    String langName = _supportedLanguages.keys.elementAt(index);
                    String langCode = _supportedLanguages.values.elementAt(
                      index,
                    );
                    bool isSelected = _selectedLang == langCode;
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: 15,
                        top: 5,
                        bottom: 5,
                      ),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedLang = langCode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: NeumorphicContainer(
                            color: isSelected
                                ? color.primaryColor
                                : neumoBaseColor,
                            isPressed: isSelected,
                            borderRadius: 25,
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Center(
                              child: Text(
                                langName,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : color.hintColor,
                                  fontWeight: isSelected
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(child: _getActiveTabContent(context)),
            ],
          );
        },
      ),
    );
  }

  Widget _getActiveTabContent(BuildContext context) {
    switch (_selectedLang) {
      case 'nso':
        return _buildHistoryTab(context, _sepediHistory);
      case 'xh':
        return _buildHistoryTab(context, _isiXhosaHistory);
      case 'st':
        return _buildHistoryTab(context, _sesothoHistory);
      case 'ts':
        return _buildHistoryTab(context, _xitsongaHistory);
      case 've':
        return _buildHistoryTab(context, _tshivendaHistory);
      case 'zu':
        return _buildHistoryTab(context, _isiZuluHistory);

      case 'en':
      default:
        return _buildHistoryTab(context, _englishHistory);
    }
  }

  Widget _buildHistoryTab(BuildContext context, String historyText) {
    final color = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: NeumorphicContainer(
              child: Text(
                " THE TACT HISTORY ",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: color.primaryColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle(historyText),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w100,
        color: Theme.of(context).primaryColor,
      ),
    ),
  );
}

const String _englishHistory = """The Twelve Apostles Church In Christ History

1832 - First Apostle J.B. Cardale
1835 - Catholic Apostolic Church founded
1852 - C.G. Klibbe was born in December
1889 - Apostle H.F. Niemeyer sent evangelist Carl George Klibbe to South Africa
1892 - Apostle C.G. Klibbe appointed as an apostle in the Apostle College in Europe
1893 - First six people are sealed in South Africa Cape Town - The church name was

New Apostolic Church
1913 - A split started as Apostle Klibbe continued with the old doctrine of the church
while Chief Apostle Niehaus disbanded the office of prophet

1926 - A South African court ruled that Apostle Klibbe must assume the new name for his group. The name was The Old Apostolic Church of Africa because Apostle Klibbe
wanted to follow the old doctrine.

1931 - In May Apostle Klibbe died. He had appointed his son in law H. Velde before he
died but he also passed away in 1956 in a car accident in Kimberly.
The Apostles that Apostle Klibbe had appointed were Apostle E. Ninow, C. Ninow and
W. Campbell
The first black apostle was Apostle Hlatshwayo, followed by Apostle Ndlovu

1972 - Apostle S.D. Phakathi was appointed by Apostle Ndlovu
They started The Twelve Apostles Church of Africa

1978 - Apostle S.D. Phakathi founded The Twelve Apostles Church In Christ
The church was officially registered in September 1978

A BRIEF HISTORY OF THE TWELVE APOSTLES CHURCH IN CHRIST
As Christians we all know that Jesus Christ is Lord, and that he has universal divine authority. Matthew says "all authority has been given to him on heaven and earth." [ Mt.28.18.] The Father placed everything into his hands.[Jhn.3.35. ] His authority has been given to him by the Father in heaven. [ Lk. 10.22.]

Let us remember that Jesus knew that he couldn't stay on earth forever. We learn from his teachings how he intended his ministry to be continued on earth. He chose twelve men and he called them his Apostles. So they could lead the church with power and authority Jesus gave them a share in his own divine authority. 
Jesus says the Apostles are sent just like the Father sent him. [ John. 20.21 ]. They are to speak the truth with the same kind of authority Jesus had, because Jesus says whoever listens to them listens to Him. [ Lk.10.16. ] 
In Jn.20.23. he specifically gives them his authority to forgive sins. Jesus must have intended his ministry to continue because in Matthew 28.20 he promises to be with the apostles until the end of time. Then in John's gospel he promises the Holy Spirit to help with the work of understanding the Truth, [ John 16.13. ] and he says the Holy Spirit will remain with The Apostles forever. [John 14.16. ]
This ministry was brought to us in Southern Africa by Evangelist Carl Geog Klibbe in 1889. He was commissioned by Apostle H.F.Niemeyer from Queensland in Australia. Since Evangelist Klibbe depended upon farming for his livehood, when he landed in Cape Town in 1889 he purchased a small holding at Bellvile, but later moved to Worcester because he could only speak german. He started his ministry by mainly focusing on german speaking community.
His testimony started bearing fruits in 1892 when an embryo congregation emerged in Southern Africa for the first time. In 1901 a shoe maker by the name of George Heinrich Schlaphoff and his family, also emigrants from Germany visited the congregation. Schlaphoff was deeply impressed by the testimony and before long he was adopted together with his family. They were sealed by Apostle Carl Klibbe on Pentacost 1902. Brother Schlaphoff made a huge impact and was highly dedicated to the work of the Lord. He later moved to Cape Town to spread the Word there.
The divine services held in the lounge of Evangelist Schlaphoff were soon well purchased. Here the first Church Hall was built and was dedicated by Apostle Klibbe on Pentacost, 4 June 1906.
The sad division between Apostle Klibbe and Evangelist Schlaphoff began in Cape Town in 1910. The exact reason for this remains disputed. This went on until there was a division among church members. The situation worsened after Schlaphoff was ordained an Apostle in Germany, and there were two groups in the church. This confusion and bitter conflict was settled in a court hearing on 26 December 1926. The court ruling was that Apostle Klibbe was to carry on his duties as "The Old Apostolic Church" and Apostle Schlaphoff retained "The New Apostolic Church" name.
Apostle Klibbe carried on with his ministry as "The Old Apostolic Church" and the church saved many souls. This made it necessary for the Lord to bless him with more Aposties until the days of Apostle F.W.Nino. Apostle Nino also contributed towards growing the church until it had a large number of black followers. Apostle Nino ordained the first Black Apostle in 1953 by the name of Samuel Hlatshwayo. Apostle Hlathwayo passed away in 1961 and Apostle Nino ordained Apostle J.S.Ndlovu.
After the passing away of Apostle Nino the relationship between Apostle J.S.Ndlovu and his white colleagues deteriorated. The root cause of this was the political situation in South Africa at the time the "Aparhteit", which led to a split in the church in 1968. Apostle J.S.Ndlovu sat quietly at his home for some time. The support he had was amazing. His supporters went to his home in numbers to encourage him to carry on with his good work. He carried on under a new name 'The Tw e l v e Apostles Church in Africa". . Knowing very well that he stood no chance against his white opposition, Apostle Ndlovu decided that this matter was not to be resolved in court, he did not even want to be in the eyes of the public or authorities. He did not allow any media or any pictures of his church gatherings taken. He always taught his followers not to mention other people's names especially the Old Apostolic Church. He only encouraged his members to preach the gospel and nothing else. He asked his followers to peacefully leave the church halls belonging to the Old Apostolic Church and gave them application letters to use school classrooms for their services. He did this under very strict regulations from the authorities. He secretly visited those schools during services to make sure they abide by the rules of the authorities. He had to apply for permission to hold large open gatherings. His divine services attracted a lot of members, especially in the townships and countries like Botswana, Swaziland and Mozambique. Things were not easy in Mozambique in such a way that at one stage he had to conduct a service in the presence of government officials who had come to witness what he was doing. He came to South Africa being very exited because the government officials in Mozambique had been touched by the Holly Spirit and gave him permission to spread the gospel in Mozambique. After that service a lot of souls were saved and sealed in many parts of Mozambique. In September 1972 he ordained Apostle S.D.Phakathi in Durban. Apostle Ndlovu dedicated his first church hall in Meadowlands Soweto in 1977.
In 1978 Apostle Ndlovu went with his delegation to Mozambique for a church service. He knew that it was not going to be a safe trip because God had already spoken. This became clear to everyone during the last farewell service he held at his new church hall in Meadowlands. During that service he spoke about things that had happened to him in the past and what could happen to him in future. That service was more like his funeral than a farewell. It was like during the last days of Jesus Christ when he was telling his Apostles about his journey to his Father in heaven. [ John 14. ] Most of those who were present and understood what God had sad, would not have allowed him to take that journey it they had a choice. With his trust in the Lord, like the Lord Jesus Christ Apostle Ndlovu was brave a n d went to Mozambique.
When Apostle Ndlovu took longer than expected to return from Mozambique, The church members became concerned because it had been already reported in one of the local newspapers that he was in trouble with the authorities in Mozambique.
When his delegation returned from Mozambique, Apostle Ndlovu and his wife were left behind. The delegation had two different reports about what had happened in Mozambique. One group confirmed the newspaper report that Apostle Ndlovu was in trouble in Mozambique. The other group said that was not true Apostle Ndlovu was conducting sealing services in Swaziland and would be coming back soon.
The group of overseers that confirmed the newspaper report, led by overseer N.V.Mlangeni, who had accompanied Apostle Ndlovu to Mozambique went to Apostle S.D.Phakathi in Durban to report what had happened in Mozambique. When they returned to Johannesburg the opposition group claimed that they went to gossip in Durban, therefore they were expelled from the church together with Apostle S.D.Phakathi. This caused a lot of tension among church members and they were divided into two groups. Apostle S.D.Phakathi had no choice but to serve the Lord under a different name until Apostle Ndlovu came back. His followers were known as "United Twelve Apostles". Months went by with no sign of Apostle Ndlovu and Apostle Phakathi registered the church as "The Twelve Apostles Church In Christ". By the time Apostle Ndlovu came back to South Africa it was too difficult to merge the two churches because the relationship between the members was still very hostile.
Apostle Phakathi carried on with his church, but still had great respect for Apostle Ndlovu, he used to call him his Father. The TACC grew at a very alarming pace under S.D.Phakathi because he introduced many activities in the church and was more focussed to the youth and the aged. He attracted people of all ages to the church. On top of all he was a very friendly person and everybody loved him especially the youth, he was their hero. The membership grew even in other countries like Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi, Zambia and Botswana. The last thanksgiving ceremony that was held at Absa stadium in Durban in September 1991, showed how much God had blessed him. Absa stadium was packed to capacity, and he ordained five Apostles on that day. The current President of the TACC N.V.Mlangeni, Deputy President N.C. Khumalo, and Apostle W.Gelem were ordained on that day. Because of the growing membership Apostle Phakathi encouraged his members to purchase a farm at Umkomaas in Durban from their own means and he started a construction of a multi-million rand church mission at Umgababa which is The Twelve Apostles Church in Christ head office today. Apostle Phakathi had great ideas for the church. He had plans to build an arena at the farm and he said the shape of it will make it easy, because it's already shaped like one. The farm is still being used for big church events today. Apostle Phakathi's passing away on 6 September 1994 came as a shock to the church members and he will always be remembered. His funeral service was held at the farm he had purchased recently. More than 40 000 members came to pay their last respect to their hero.
It was like a double blow to the already shaken church members when there was a division between the remaining Apostles, regarding who will be the "HEAD" of the church. The name "HEAD" became very popular and it upset the stomachs of many, especially those who came to the church to worship. The church split into two groups. Apostle N.V.Mlangeni was elected the new president by Apostle N.C. Khumalo who was the church co-ordinator at the time in 1995, and Apostle Khumalo was the deputy. On 29 November 1995 two groups celebrated their thanksgiving day at the farm but separately. Apostles C.Nongqunga and W.Gelem on one section of the farm with their followers and Apostles N.V.Mlangeni and N.C. Khumalo on the main arena of the farm with their follwers. This was a very heart breaking situation to witness.
There were tears of joy and happiness when Apostle W.Gelem and his followers returned to the church in 1997.He was welcomed unconditionally with warm hearts by the Apotles N.V.Mlangeni and N.C.Khumalo and all the church members. This action seemed to heal the wounds of the past. Apostle W.Gelem really blessed the children of God with his powerful teachings, he had nothing but fire. He played a big role in merging the two groups to one united church with his powerful and divine services throughout the country and abroad. His last message to the church members wherever he went during his last days was Matthew [5.8] blessed are the pure in heart for they shall see God. Apostle W. Gelem was no longer a healthy man at that time and he passed away in 1998. His teachings are still alive todate. "Blessed are the pure in heart for they shall see God". 

He was buried at his home yard at Tsolo in the Eastern Cape.
Apostle Mlangeni and Apostle Khumalo continued with the testimony and the church membership has today grown by at least 300% in comparison to the membership during the days of Apostle S.D.Phakathi in 1994. 

Kwazulu Natal represents a large percentage of membership. Mozambique also has a substantial number of membership.The firt sealing service was held in Angola in 2006. Overseer John Mthembu does a very remarkable work in couries like Malawi, D.R.Congo, and Angola. The Church is growing in those countries. Apostle Miangeni has ordained ten Apostles up to today. In South Africa we have Apostles J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu and E.Mzamo. In Mozambique Apostles Ntimbane, Mthise, Bazar and the late apostles""";

const String _sepediHistory = """Histori ya The Twelve Apostles Church In Christ

1832 - Moapostola wa mathomo J.B. Cardale
1835 - Kereke ya Catholic Apostolic e theilwe
1852 - C.G. Klibbe o belegwe ka Desemere
1889 - Moapostola H.F. Niemeyer o rometše moevangeli Carl George Klibbe Afrika Borwa
1892 - Moapostola C.G. Klibbe o kgethilwe go ba moapostola Kholejing ya Baapostola kua Yuropa
1893 - Batho ba tshela ba mathomo ba tiišeditšwe Afrika Borwa, Motsekapa - Leina la kereke e be e le
New Apostolic Church
1913 - Karogano e thomile ge Moapostola Klibbe a tšwela pele ka thuto ya kgale ya kereke,
mola Moapostola yo Mogolo Niehaus a phumotše ofisi ya moporofeta.
1926 - Kgoro ya Tsheko ya Afrika Borwa e laetše gore Moapostola Klibbe a tšee leina le leswa la sehlopha sa gagwe. Leina le e be e le The Old Apostolic Church of Africa ka gobane Moapostola Klibbe o be a nyaka go latela thuto ya kgale.
1931 - Ka Motsheganong Moapostola Klibbe o hlokofetše. O be a kgethile mokgonyana wa gagwe H. Velde pele a hlokofala, eupša le yena o hlokofetše ka 1956 kotsing ya sefatanaga kua Kimberly.
Baapostola bao Moapostola Klibbe a ba kgethilego e be e le Moapostola E. Ninow, C. Ninow le W. Campbell.
Moapostola wa mathomo wa mothomoso e bile Moapostola Hlatshwayo, a latelwa ke Moapostola Ndlovu.
1972 - Moapostola S.D. Phakathi o kgethilwe ke Moapostola Ndlovu.
Ba thomile The Twelve Apostles Church of Africa.
1978 - Moapostola S.D. Phakathi o theile The Twelve Apostles Church In Christ.
Kereke e ngwadišitšwe semolao ka Lewedi 1978.

KAKARETŠO YA HISTORI YA THE TWELVE APOSTLES CHURCH IN CHRIST
Bjalo ka Bakriste ka moka re a tseba gore Jesu Kriste ke Morena, le gore o na le maatla a magolo a legodimo. Mattheo o re "maatla ohle a filwe yena legodimong le lefaseng." [ Mat.28.18.] Tate o beile tšohle diatleng tša gagwe.[Joh.3.35. ] Maatla a gagwe o a filwe ke Tate legodimong. [ Luk. 10.22.]

A re gopoleng gore Jesu o be a tseba gore a ka se dule lefaseng go ya go ile. Re ithuta thutong ya gagwe ka moo a bego a nyaka bodiredi bja gagwe bo tšwele pele lefaseng. O kgethile banna ba lesome le metšo e mebedi mme a ba bitša Baapostola ba gagwe. Gore ba ketele kereke pele ka maatla le taolo, Jesu o ba file karolo ya maatla a gagwe a legodimo.
Jesu o re Baapostola ba romilwe go swana le ka moo Tate a mo romilego. [ Joh. 20.21 ]. Ba swanetše go bolela therešo ka maatla a go swana le a Jesu, ka gobane Jesu o re mang le mang yo a ba theetšago, o theetša Yena. [ Luk.10.16. ]
Go Joh.20.23. o ba fa maatla a gagwe go swarela dibe. Jesu o swanetše go ba a be a nyaka gore bodiredi bja gagwe bo tšwele pele ka gobane go Mattheo 28.20 o holofetša go ba le baapostola go fihla bofelong bja nako. Ka morago ebangeding ya Johane o holofetša Moya o Mokgethwa go thuša ka modiro wa go kwešiša Therešo, [ Joh 16.13. ] mme o re Moya o Mokgethwa o tla dula le Baapostola go ya go ile. [Joh 14.16. ]
Bodiredi bjo bo tlišitšwe go rena mo Afrika Borwa ke Moevangeli Carl Geog Klibbe ka 1889. O be a romilwe ke Moapostola H.F.Niemeyer wa Queensland kua Australia. Ka ge Moevangeli Klibbe a be a tshepile temo go iphediša, e rile ge a fihla Motsekapa ka 1889 a reka polasa e nnyane kua Bellvile, eupša ka morago a hudugela Worcester ka gobane a be a kgona go bolela Sejeremane fela. O thomile bodiredi bja gagwe ka go tsepamisa monagano kudu setšhabeng se se bolelago Sejeremane.
Bohlatse bja gagwe bo thomile go enywa dienywa ka 1892 ge phuthego ya mathomo e tšwelela mo Afrika Borwa la mathomo. Ka 1901 moroki wa dieta yo a bitšwago George Heinrich Schlaphoff le lapa la gagwe, bao le bona e bego e le bafaladi go tšwa Jeremane, ba etetše phuthego. Schlaphoff o kgahlilwe kudu ke bohlatse gomme ka moragonyana a amogelwa gotee le lapa la gagwe. Ba tiišeditšwe ke Moapostola Carl Klibbe ka Pentekoste 1902. Ngwanabo rena Schlaphoff o dirile seabe se segolo mme a ikgafa kudu modirong wa Morena. Ka morago o hudugetše Motsekapa go phatlalatša Lentšu moo.
Ditirelo tša sekgethwa tšeo di bego di swarelwa ka phapošing ya Moevangeli Schlaphoff di be di tsenelwa kudu. Fa go ile gwa agwa Kereke ya mathomo mme ya abelwa ke Moapostola Klibbe ka Pentekoste, 4 June 1906.
Karogano e bohloko magareng ga Moapostola Klibbe le Moevangeli Schlaphoff e thomile Motsekapa ka 1910. Lebaka le le nnete la se le sa dutše le ngangišanwa. Se se tšweletše go fihlela go e-ba le karogano magareng ga maloko a kereke. Boemo bo ile bja mpefala ka morago ga ge Schlaphoff a kgethilwe go ba Moapostola kua Jeremane, gomme go be go na le dihlopha tše pedi kerekeng. Tlhakatlhakano ye le thulano e bohloko di rarolotšwe theetšong ya kgoro ya tsheko ka di 26 December 1926. Sephetho sa kgoro e bile sa gore Moapostola Klibbe a tšwele pele ka mediro ya gagwe e le "The Old Apostolic Church" mme Moapostola Schlaphoff a boloka leina la "The New Apostolic Church".
Moapostola Klibbe o tšwetše pele ka bodiredi bja gagwe e le "The Old Apostolic Church" mme kereke ya phološa meoya e mentši. Se se dirile gore go be bohlokwa gore Morena a mo šegofatše ka Baapostola ba bangwe go fihla matšatšing a Moapostola F.W.Nino. Moapostola Nino le yena o kentše letsogo kgolong ya kereke go fihlela e e-ba le palo e kgolo ya balatedi ba bathobaso. Moapostola Nino o kgethile Moapostola wa Mathomo wa Mothomaso ka 1953 ka leina la Samuel Hlatshwayo. Moapostola Hlathwayo o hlokofetše ka 1961 gomme Moapostola Nino a kgetha Moapostola J.S.Ndlovu.
Ka morago ga go hlokofala ga Moapostola Nino tswalano magareng ga Moapostola J.S.Ndlovu le bašomimmogo ba gagwe ba bašweu e ile ya senyega. Lebaka le legolo la se e be e le maemo a sepolotiki mo Afrika Borwa ka nako yeo ya "Kgethologanyo", yeo e tlišitšego karogano kerekeng ka 1968. Moapostola J.S.Ndlovu o dutše ka setu gae ganyane. Thekgo ye a bago le yona e be e makatša. Bathekgi ba gagwe ba ile ba ya gae ka bontši go mo hlohleletša go tšwela pele ka modiro wa gagwe o mobotse. O tšwetše pele ka tlase ga leina le leswa "The Twelve Apostles Church in Africa". Ka ge a be a tseba gabotse gore a ka se kgone go lwantšhana le baganetši ba gagwe ba bašweu, Moapostola Ndlovu o dirile phetho ya gore taba ye e ka se rarollwe kgorong ya tsheko, o be a sa nyake le go ba mahlong a setšhaba goba a balaodi. Ga se a dumelela gore go tšewe diswantšho tša dikopano tša kereke ya gagwe goba bobegadikgang bofe. O be a dula a ruta balatedi ba gagwe gore ba se tsoge ba boletše maina a batho ba bangwe kudu Old Apostolic Church. O be a hlohleletša maloko a gagwe go rera efangele fela e sego se sengwe. O kgopetše balatedi ba gagwe gore ba tlogele ka khutšo diholo tša kereke tša Old Apostolic Church gomme a ba fa mangwalo a kgopelo a go šomiša diphapoši tša sekolo bakeng sa ditirelo tša bona. O dirile se ka tlase ga melawana e thata ya balaodi. O be a etela dikolo tšeo ka sephiri nakong ya ditirelo go netefatša gore ba obamela melawana ya balaodi. O be a swanetše go kgopela tumelelo ya go swara dikopano tše dikgolo tša ka ntle. Ditirelo tša gagwe tša sekgethwa di gogetše maloko a mantši, kudu makeišaneng le dinageng tša go swana le Botswana, Swaziland le Mozambique. Dilo di be di se bonolo Mozambique mo e lego gore ka nako e nngwe o be a swanetše go swara tirelo pele ga bahlankedi ba mmušo bao ba bego ba tlile go bona se a bego a se dira. O tlile Afrika Borwa a thabile kudu ka gobane bahlankedi ba mmušo ba Mozambique ba be ba kgongwa ke Moya o Mokgethwa gomme ba mo fa tumelelo ya go phatlalatša efangele Mozambique. Ka morago ga tirelo yeo meoya e mentši e phološitšwe gomme ya tiišetšwa dikarolong tše dintši tša Mozambique. Ka September 1972 o kgethile Moapostola S.D.Phakathi kua Durban. Moapostola Ndlovu o abetše holo ya gagwe ya mathomo ya kereke kua Meadowlands Soweto ka 1977.
Ka 1978 Moapostola Ndlovu o ile le baemedi ba gagwe Mozambique bakeng sa tirelo ya kereke. O be a tseba gore e ka se be leeto le le bolutegilego ka gobane Modimo o be a šetše a boletše. Se se bile molaleng go bohle nakong ya tirelo ya mafelelo ya go laelana yeo a e swaretšego holong ya gagwe e mpsha ya kereke kua Meadowlands. Nakong ya tirelo yeo o boletše ka dilo tšeo di mo hlagetšego nakong e fetilego le tšeo di ka mo hlagelago nakong e tlago. Tirelo yeo e be e le ya go swana le phitlho ya gagwe go e na le go laelana. E be e le go swana le matšatšing a mafelelo a Jesu Kriste ge a be a botša Baapostola ba gagwe ka leeto la gagwe la go ya go Tatagwe legodimong. [ Johane 14. ] Ba bantši ba bao ba bego ba le gona gomme ba kwešiša se Modimo a se boletšego, ba be ba ka se mo dumelele go tšea leeto leo ge ba be ba na le kgetho. Ka kholofelo ya gagwe go Morena, go swana le Morena Jesu Kriste Moapostola Ndlovu o bile le sebete mme a ya Mozambique.
Ge Moapostola Ndlovu a tšea nako e telele go feta ka mo go bego go letetšwe gore a boe Mozambique, maloko a kereke a ile a tshwenyega ka gobane go be go šetše go begilwe go e nngwe ya dikuranta tša legae gore o na le mathata le balaodi ba Mozambique.
Ge baemedi ba gagwe ba boa Mozambique, Moapostola Ndlovu le mosadi wa gagwe ba be ba šetše morago. Baemedi ba be ba na le dipego tše pedi tša go fapana mabapi le se se hlagilego Mozambique. Sehlopha se sengwe se tiišeditše pego ya kuranta ya gore Moapostola Ndlovu o bothateng Mozambique. Sehlopha se sengwe se itše seo ga se nnete, Moapostola Ndlovu o be a swara ditirelo tša go tiišetša Swaziland gomme o tla boa e se kgale.
Sehlopha sa balebeledi seo se tiišeditšego pego ya kuranta, seo se bego se etetšwe pele ke molebeledi N.V.Mlangeni, yo a bego a felegetša Moapostola Ndlovu go ya Mozambique se ile go Moapostola S.D.Phakathi kua Durban go bega se se hlagilego Mozambique. Ge ba boela Johannesburg sehlopha se se ganetšago se ile sa bolela gore ba ile go seba Durban, ka fao ba rakwa kerekeng gotee le Moapostola S.D.Phakathi. Se se tlišitše tsitsing e kgolo magareng ga maloko a kereke gomme ba kgaoganngwa ka dihlopha tše pedi. Moapostola S.D.Phakathi o be a se na kgetho e nngwe ge e se go direla Morena ka tlase ga leina le lengwe go fihlela Moapostola Ndlovu a boa. Balatedi ba gagwe ba be ba tsebja bjalo ka "United Twelve Apostles". Dikgwedi tša feta go se na leswao la Moapostola Ndlovu gomme Moapostola Phakathi o ngwadišitše kereke e le "The Twelve Apostles Church In Christ". Ka nako ye Moapostola Ndlovu a boago mo Afrika Borwa go be go le thata kudu go kopanya dikereke tše pedi ka gobane tswalano magareng ga maloko e be e sa le e mpe kudu.
Moapostola Phakathi o tšwetše pele ka kereke ya gagwe, eupša o be a sa hlompha Moapostola Ndlovu kudu, o be a mo bitša Tatagwe. TACC e gotše ka lebelo le legolo kudu ka tlase ga S.D.Phakathi ka gobane o tlišitše mešongwana e mentši kerekeng gomme a tsepamiša monagano kudu go bafsa le batšofadi. O gogetše batho ba mengwaga ka moka kerekeng. Ka godimo ga tšohle e be e le motho wa segwera kudu gomme motho yo mongwe le yo mongwe o be a mo rata kudu bafsa, e be e le mogale wa bona. Maloko a oketšegile le go dinaga tše dingwe tša go swana le Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi, Zambia le Botswana. Monyanya wa mafelelo wa tebogo wo o bego o swaretšwe lebaleng la Absa kua Durban ka September 1991, o laeditše ka moo Modimo a mo šegofaditšego ka gona. Lebala la Absa le be le tletše phaa, gomme a kgetha Baapostola ba bahlano ka letšatši leo. Mopresidente wa ga bjale wa TACC N.V.Mlangeni, Motlatšamopresidente N.C. Khumalo, le Moapostola W.Gelem ba kgethilwe ka letšatši leo. Ka baka la koketšego ya maloko Moapostola Phakathi o hlohleleditše maloko a gagwe go reka polasa kua Umkomaas kua Durban ka mašeleng a bona gomme a thoma kago ya mofeto wa dimilione tša diranta wa kereke kua Umgababa yeo e lego ofisi e kgolo ya The Twelve Apostles Church in Christ lehono. Moapostola Phakathi o be a na le dikgopolo tše dikgolo ka kereke. O be a e-na le maikemišetšo a go aga lebala polaseng mme a re sebopego sa lona se tla dira gore go be bonolo, ka gobane le šetše le bopilwe go swana le lona. Polasa e sa šomišetšwa ditiragalo tše dikgolo tša kereke lehono. Go hlokofala ga Moapostola Phakathi ka di 6 September 1994 go tlile e le tšhogo go maloko a kereke mme o tla dula a gopolwa nako ka moka. Tirelo ya gagwe ya phitlho e be e swaretšwe polaseng yeo a sa tšwago go e reka. Maloko a go feta 40 000 a tlile go fa hlompho ya mafelelo go mogale wa bona.
E be e le bjalo ka kotsi e habeli go maloko a kereke ao a šetšego a tšhogile ge go e-ba le karogano magareng ga Baapostola ba ba šetšego, mabapi le gore ke mang yo a tlago ba "HLOGO" ya kereke. Leina "HLOGO" le tumile kudu gomme la senya dimpa tša ba bantši, kudu bao ba bego ba tlile kerekeng go rapela. Kereke e kgaogane ka dihlopha tše pedi. Moapostola N.V.Mlangeni o kgethilwe bjalo ka mopresidente o moswa ke Moapostola N.C. Khumalo yo a bego a le molomaganyi wa kereke ka nako yeo ka 1995, gomme Moapostola Khumalo a ba motlatša. Ka di 29 November 1995 dihlopha tše pedi di ketekile letšatši la tšona la tebogo polaseng eupša ka go kgaogana. Baapostola C.Nongqunga le W.Gelem lefelong le lengwe la polasa le balatedi ba bona le Baapostola N.V.Mlangeni le N.C. Khumalo lebaleng le legolo la polasa le balatedi ba bona. Se e be e le boemo bjo bo nyamišago kudu go bo bona.
Go bile le megokgo ya lethabo ge Moapostola W.Gelem le balatedi ba gagwe ba boela kerekeng ka 1997. O amogetšwe ntle le dipeelano ka dipelo tše borutho ke Baapostola N.V.Mlangeni le N.C.Khumalo le maloko ka moka a kereke. Ketso ye e be e bonagala e fodiša dintho tša nako e fetilego. Moapostola W.Gelem o tloga a šegofaditše bana ba Modimo ka dithuto tša gagwe tše maatla, o be a se na selo ge e se mollo fela. O kgathile tema e kgolo kudu go kopanya dihlopha tše pedi go ba kereke e tee e kopanego ka ditirelo tša gagwe tše maatla le tša sekgethwa nageng ka moka le dinageng tša ka ntle. Molaetša wa gagwe wa mafelelo go maloko a kereke gohle moo a yago gona matšatšing a gagwe a mafelelo e be e le Mattheo [5.8] ba lehlogonolo ba ba hlwekilego pelong, gobane ba tla bona Modimo. Moapostola W. Gelem o be a sa hlwa a le motho yo a phetšego gabotse ka nako yeo mme o hlokofetše ka 1998. Dithuto tša gagwe di sa phela le lehono. "Ba lehlogonolo ba ba hlwekilego pelong, gobane ba tla bona Modimo".

O bolokilwe lelapeng la gagwe kua Tsolo Kapa Bohlabela.
Moapostola Mlangeni le Moapostola Khumalo ba tšwetše pele ka bohlatse gomme maloko a kereke lehono a gotše ka bonyenyane 300% ge a bapetšwa le maloko mehleng ya Moapostola S.D.Phakathi ka 1994.

Kwazulu Natal e emela phesente e kgolo ya maloko. Mozambique le yona e na le palo e kgolo ya maloko. Tirelo ya mathomo ya go tiišetša e be e swaretšwe Angola ka 2006. Molebeledi John Mthembu o dira modiro o mogolo kudu dinageng tša go swana le Malawi, D.R.Congo, le Angola. Kereke e a gola dinageng tšeo. Moapostola Miangeni o kgethile Baapostola ba lesome go fihla lehono. Mo Afrika Borwa re na le Baapostola J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu le E.Mzamo. Mozambique Baapostola Ntimbane, Mthise, Bazar le baapostola bao ba hlokofetšego.""";

const String _tshivendaHistory =
    """Divhazwakale Ya Kereke Ya The Twelve Apostles Church In Christ

1832 - Muapostola wa u thoma J.B. Cardale
1835 - Kereke ya Catholic Apostolic ya thomiwa
1852 - C.G. Klibbe o bebiwa nga Nyendavhusiku
1889 - Muapostola H.F. Niemeyer o ruma muvangeli Carl George Klibbe Afurika Tshipembe
1892 - Muapostola C.G. Klibbe o vhewa sa muapostola ngei Kholodzhini ya Vhaapostola Yuropa
1893 - Vhathu vha rathi vha u thoma vha tou vhewa tswayo Afurika Tshipembe Kapa - Dzina la kereke lo vha li
New Apostolic Church
1913 - U fhandekana ho thoma musi Muapostola Klibbe a tshi bvela phanda na pfunzo ya kale ya kereke
ngeno Muapostola Muhulwane Niehaus a tshi pwashekanya ofisi ya muporofita.
1926 - Khothe ya Afurika Tshipembe ya ri Muapostola Klibbe a dzhie dzina liswa la tshigwada tshawe. Dzina lo vha The Old Apostolic Church of Africa ngauri Muapostola Klibbe o vha a tshi toda u tevhela pfunzo ya kale.
1931 - Ngo Shundunthule Muapostola Klibbe o lovha. O vha o vhea mukwasha wawe H. Velde phanda ha u lovha hawe fhedzi na ene o lovha ngo 1956 kha khombo ya goloi ngei Kimberly.
Vhaapostola vhe Muapostola Klibbe a vha vhea ho vha e Muapostola E. Ninow, C. Ninow na W. Campbell.
Muapostola wa u thoma mutswu o vha e Muapostola Hlatshwayo, a tevhelwa nga Muapostola Ndlovu.
1972 - Muapostola S.D. Phakathi o vhewa nga Muapostola Ndlovu.
Vha thoma The Twelve Apostles Church of Africa.
1978 - Muapostola S.D. Phakathi a thoma The Twelve Apostles Church In Christ.
Kereke yo redzisitariwa tshiokofisiala nga Tshimedzi 1978.

PFUFHI YA DIVHAZWAKALE YA THE TWELVE APOSTLES CHURCH IN CHRIST
Sa Vhakriste rothe ri a divha uri Yesu Khristo ndi Murena, nahone u na maanda manwe na manwe a tadulu na fhasi. Mateo u ri "maanda othe o newa ene tadulu na fhasi." [ Mat.28.18.] Khotsi o vhea zwithu zwothe zwanani zwawe.[Yoh.3.35. ] Maanda awe o newa nga Khotsi tadulu. [ Luk. 10.22.]

Kha ri humbule uri Yesu o vha a tshi divha uri ha nga dzuli shangoni lwa tshothe. Ri guda kha pfunzo dzawe uri o vha a tshi humbula hani uri vhudinda hawe vhu bvele phanda shangoni. O nanga vhanna vha fumi na vhavhili a vha vhidza Vhaapostola vhawe. Uri vha kone u ranga phanda kereke nga maanda na thendo, Yesu o vha nea mukovhe wa maanda awe a tadulu.
Yesu u ri Vhaapostola vho rumiwa fhedzi unga Khotsi o mu ruma. [ Yoh. 20.21 ]. Vha fanela u amba ngoho nga maanda mawanwe e Yesu a vha nao, ngauri Yesu u ri onoyo ane a vha pfa u pfa Ene. [ Luk.10.16. ]
Kha Yoh.20.23. o vha nea nga maanda thendo dza u hangwela zwivhi. Yesu o tea u vha o lavhelela uri vhudinda hawe vhu bvele phanda ngauri kha Mateo 28.20 u fulufhedzisa u vha na vhaapostola u swika vhufheloni ha tshifhinga. Nga murahu buguni ya Yohane u fulufhedzisa Muya Mukhethwa uri u thuse nga mushumo wa u pfesesesa Ngoho, [ Yoh 16.13. ] nahone u ri Muya Mukhethwa u do dzula na Vhaapostola lwa tshothe. [Yoh 14.16. ]
Vhudinda uho ho diswa kha rine Afurika Tshipembe nga Muvangeli Carl Geog Klibbe ngo 1889. O rumiwa nga Muapostola H.F.Niemeyer wa Queensland Australia. Ngauri Muvangeli Klibbe o vha a tshi thetshelesa vhulimi uri a tshile, musi a tshi swika Kapa ngo 1889 o renga bulasi thukhu Bellvile, fhedzi nga murahu a pfulutshela Worcester ngauri o vha a tshi kona fhedzi u amba Tshidzheremane. O thoma vhudinda hawe nga u sedza vhathu vha ambaho Tshidzheremane fhedzi.
Vhuthanzi hawe ho thoma u aṋwa mitshelo ngo 1892 musi tshivhidzo tshituku tshi tshi bvelela Afurika Tshipembe lwa u thoma. Ngo 1901 murema zwienda a no pfi George Heinrich Schlaphoff na muta wawe, vhe na vhone vha vha vhabvanda bva Dzheremane, vho dalela tshivhidzo. Schlaphoff o kungiwa nga maanda nga vhuthanzi nahone hu si kale o no tanganedzwa khathihi na muta wawe. Vho vhewa tswayo nga Muapostola Carl Klibbe nga Pentekhosite ngo 1902. Mukomana Schlaphoff o bveledza tshanduko khulwane nahone o vha o diimisela vhukuma kha mushumo wa Murena. Nga murahu a pfulutshela Kapa u phadaladza Ipfi henefho.
Tshumelo dza Mudzimu dze dza farwa phuruni ya Muvangeli Schlaphoff dzo mbo di dzhenelwa nga vhanzhi. Afha ndu ya u thoma ya Kereke yo fhatiwa nahone ya nekedzwa nga Muapostola Klibbe nga Pentekhosite, 4 Fulwi 1906.
Phambano mbvuvhi vhukati ha Muapostola Klibbe na Muvangeli Schlaphoff yo thoma Kapa ngo 1910. Zwi re zwone zwo zwi vangaho zwi kha di hanwa. Hezwi zwo bvela phanda u swika hu na phambano vhukati ha mirado ya kereke. Zwo vhifha musi Schlaphoff a tshi vhewa Muapostola Dzheremane, nahone ho vha hu na zwigwada zwivhili kerekeng. Phirithano iyi na khani mbevhi dzo fhedzwa dzikhothotheni dza milandu nga 26 Nyendavhusiku 1926. Tsheo ya khotho yo vha ya uri Muapostola Klibbe a bvele phanda na mishumo yawe unga "The Old Apostolic Church" nahone Muapostola Schlaphoff o tuwa na dzina la "The New Apostolic Church".
Muapostola Klibbe o bvela phanda na vhudinda hawe sa "The Old Apostolic Church" nahone kereke yo phulusa mimuya minzhi. Hezwi zwo ita uri zwi vhe zwa ndeme uri Murena a mu fhatutshedze nga Vhaapostola vhanwe u swika maduvhani a Muapostola F.W.Nino. Muapostola Nino na ene o thusa kha u alusa kereke u swika i na tshivhalo tshihulwane tsha vhatevheli vhatswu. Muapostola Nino o vhea Muapostola wa u thoma Mutswu ngo 1953 nga dzina la Samuel Hlatshwayo. Muapostola Hlatshwayo o lovha ngo 1961 nahone Muapostola Nino a vhea Muapostola J.S.Ndlovu.
Nga murahu ha u lovha ha Muapostola Nino vhushaka vhukati ha Muapostola J.S.Ndlovu na vhashumisani vhawe vhatshena vho mbo di tshinyala. Tsho vangaho vhukuma zwo vha zwi tshi elana na zwa politiki Afurika Tshipembe tshipingani tshenetsho tsha "Khethululano" (Apartheid), zwe zwa vanga u fhandekana kerekeng ngo 1968. Muapostola J.S.Ndlovu o dzula hayani o fhumula tshifhinganyana. Thikhedzo ye a vha e nayo yo vha i tshi mangadza. Vhatikhedzi vhawe vho ya hayani hawe nga vhunzhi u mu thutuwedza uri a bvele phanda na mushumo wawe wavhudi. O bvela phanda nga fhasi ha dzina liswa 'The Twelve Apostles Church in Africa". A tshi divha zwavhudi uri ha nga koni u lwisana na vhapikisi vhawe vhatshena, Muapostola Ndlovu o dzhia tsheo ya uri enea mafhungo ha nga fhedzwi khothoni, o vha a sa todi na u vhonala phanda ha tshitshavha kana vhavhusi. Ho ngo tendela vha masia-nda-vha-tshi-wana kana u thothwa zwifanyiso zwine zwa sumbedza maguvhangano a kereke yawe. O vha a tshi dzulela u funza vhatevheli vhawe uri vha songo amba madzina a vhanwe vhathu nga maanda the Old Apostolic Church. O khuthadza fhedzi mirado yawe uri vha rere evangeli naho hu si zwinwevho. O humbela vhatevheli vhawe uri vha bve nga mulalo holoni dza kereke dza the Old Apostolic Church a vha nea dziburuvhero u shumisa makilasi a zwikolo vhudindani havho. O ita hezwi nga fhasi ha milayo yo khwathaho ya vhavhusi. O dalela zwikolo zwenezwo tshiphirini zwifhingani zwa tshumelo u vhona uri vha tevhela milayo ya vhavhusi. O vha a fanela u humbela thevheledzo dza u fara maguvhangano mahulwane a nnada. Tshumelo dzawe dza lwa muya dzo kunga mirado minzhi, nga maanda zwaloni na mashangoni a fana na Botswana, Swaziland na Mozambique. Zwithu zwo vha zwi si zwo leluwaho ngei Mozambique lwe ndilani o pfa a tshi fanyiswa u fara tshumelo phanda ha vhashumeli vha muvhuso vhe vha da u vhona zwe a vha a tshi khou ita. O da Afurika Tshipembe o takala vhukuma ngauri vhashumeli vha muvhuso wa Mozambique vho kwamiwa nga Muya Mukhethwa nahone vha mu tendela u phadaladza evangeli ngei Mozambique. Nga murahu ha tshumelo yeneyo mimuya minzhi yo phuluswa nahone ya vhewa tswayo fhethu hunzhi Mozambique. Ngo Khubvumedzi 1972 o vhea Muapostola S.D.Phakathi ngei Durban. Muapostola Ndlovu o nekedza holo yawe ya kereke ya u thoma ngei Meadowlands Soweto ngo 1977.
Ngo 1978 Muapostola Ndlovu o tuwa na vharunwa vhawe vha ya Mozambique tshumeloni ya kereke. O vha a tshi zwi divha uri lu si do vha lwendo lwo tsireledzeaho ngauri Mudzimu o vha o no amba. Hezwi zwo vha khagala kha vhothe tshumeloni ya u fhedzisela ye a i fara ngei holoni ya kereke ntswa ya Meadowlands. Kha yeneyo tshumelo o amba nga zwithu zwe zwa mu wela tshifhingani tsho fhelaho na zwe zwa nga mu wela tshifhingani tshi daho. Yeneyo tshumelo yo vha i tshi fana na mbulungo yawe u fhira u laya. Zwo vha zwi tshi fana na maduvhani a u fhedzisela a Yesu Khristo musi a tshi khou vhudza Vhaapostola vhawe nga lwendo lwawe lwa u ya ha Khotsi awe tadulu. [ Yohane 14. ] Vhanzhi vha vhe vha vha hone nahone vho pfesesa zwe Mudzimu a amba, vho vha vha sa do mu tendela u dzhia lwonolo lwendo arali vho vha vhe na nungo. Nga u fulufhela Murena, fana na Murena Yesu Khristo Muapostola Ndlovu o vha na tshivhindi nahone o ya Mozambique.
Musi Muapostola Ndlovu a tshi dzhia tshifhinga tshilapfu u fhira tsho lavhelelwaho u vhuya Mozambique, mirado ya kereke ya mbo di vhilaela ngauri ho vha ho no thetshelelwa kha linwe la magurannanda a henefho uri o vha khomboni na vhavhusi ngei Mozambique.
Musi vharunwa vhawe vha tshi vhuya Mozambique, Muapostola Ndlovu na mufumakadzi wawe vho salela murahu. Vharunwa vho vha vhe na mivhigo mivhili yo fhambanaho nga ha zwe zwa itea Mozambique. Tshigwada tshithihi tsho khwathisedza muvhigo wa gurannanda uri Muapostola Ndlovu o vha e khomboni ngei Mozambique. Tshinwe tshigwada tsha ri a si ngoho Muapostola Ndlovu o vha a tshi khou fara tshumelo dza u vhea tswayo ngei Swaziland nahone u do vhuya hu si kale.
Tshigwada tsha vhalavhelesi tshe tsha khwathisedza muvhigo wa gurannanda, tsho rangelwa nga mulavhelesi N.V.Mlangeni, we a fhelekedza Muapostola Ndlovu u ya Mozambique tsho ya ha Muapostola S.D.Phakathi ngei Durban u mu vhudza zwe zwa itea Mozambique. Musi vha tshi vhuyelela Johannesburg tshigwada tshihanganisi tsha ri vho ya u zwifha eThekwini, zwenezwo vha thathiwa kerekeng khathihi na Muapostola S.D.Phakathi. Hezwi zwo disa mutsiko muhulwane vhukati ha mirado ya kereke nahone vha fhandekana zwigwada zwivhili. Muapostola S.D.Phakathi o vha a si na inwe ndila nga nnda ha u shumela Murena nga fhasi ha dzina linwe u swikela Muapostola Ndlovu a tshi vhuya. Vhatevheli vhawe vho vha vha tshi divhiwa sa "United Twelve Apostles". Mienwedzi ya fhela hu sina tswayo ya Muapostola Ndlovu nahone Muapostola Phakathi o redzisitara kereke unga "The Twelve Apostles Church In Christ". Nga tshifhinga tshe Muapostola Ndlovu a vhuya Afurika Tshipembe zwo vha zwi tshi konda vhukuma u tanganya kereke dzezo mbili ngauri vhushaka vhukati ha mirado ho vha hu kha di vha na vengo fulu.
Muapostola Phakathi o bvela phanda na kereke yawe, fhedzi o vha a kha di hulisa vhukuma Muapostola Ndlovu, o vha a tshi anzela u mu vhidza Khotsi awe. TACC ya aluwa nga luvhilo luhulwane nga fhasi ha S.D.Phakathi ngauri o disa mishumo minzhi kerekeng nahone o vha a tshi lavhelesa vhaswa na vhalala. O kunga vhathu vha minwaha yothe kerekeng. Ntha ha zwothe o vha e muthu wa tshigwema nahone muthu munwe na munwe o vha a tshi mu funa nga maanda vhaswa, o vha e gamba lavho. Vhathu vho engedzea na kha manwe mashango a fana na Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi, Zambia na Botswana. Vhutambo ha u fhedzisela ha u livhuha he ha farwa khadeni ya Absa ngei Durban ngo Khubvumedzi 1991, ho sumbedza uri Mudzimu o mu fhatutshedza lungafhani. Dzithediyamu ya Absa yo vha yo dala, nahone o vhea Vhaapostola vhatanu ngelo duvha. Phuresidende wa zwino wa TACC N.V.Mlangeni, Phuresidende wa Vhuvhili N.C. Khumalo, na Muapostola W.Gelem vho vhewa nga ilo duvha. Nga u aluwa ha vhathu Muapostola Phakathi o khuthadza mirado yawe uri i renge bulasi ngei Umkomaas eThekwini nga zwishumiswa zwavho nahone a thoma fhato la kereke la dzimilioni dza dirannda ngei Umgababa ine ya vha ofisi khulwane ya The Twelve Apostles Church in Christ namusi. Muapostola Phakathi o vha e na dzimbuno khulwane nga kereke. O vha e na zwikongomelo zwa u fhata tshitati bulasini nahone a ri tshivhumbeo tshatsho tshi do leludza, ngauri yo no vhumbwa unga yone. Bulasi i kha di shumiswa kha zwiitea zwihulwane zwa kereke namusi. U lovha ha Muapostola Phakathi nga 6 Khubvumedzi 1994 ho da sa tshithu tsho tsha kerekeng nahone u do dzula a tshi humbulwa. Tshumelo yawe ya mbulungo yo farwa kha bulasi ye a r'enga zwi sa athu fhela. Mirado i fhiraho 40 000 yo da u nea thonifho dzavho dza u fhedzisela kha gamba lavho.
Zwo vha zwi tshi nga thamu mbili kha mirado ya kereke ye ya vha yo no di dzinginyiswa musi hu tshi vha na phambano vhukati ha Vhaapostola vho salaho, malugana na uri nnyi ane a do vha "THOHO" ya kereke. Dzina "THOHO" lo duma vhukuma nahone lo dina dzimbu dza vhanzhi, nga maanda vhe vha da kerekeng u rabela. Kereke ya fhandekana zwigwada zwivhili. Muapostola N.V.Mlangeni o nangiwa sa phuresidende muswa nga Muapostola N.C. Khumalo we a vha e mutanganyi wa kereke nga tshenetsho tshifhinga ngo 1995, nahone Muapostola Khumalo o vha mutikedzi wawe. Nga 29 Luhuhi 1995 zwigwada zwivhili zwo pembelela duvha lazwo la u livhuha bulasini fhedzi vho fhandekana. Vhaapostola C.Nongqunga na W.Gelem khetheni inwe ya bulasi na vhatevheli vhavho na Vhaapostola N.V.Mlangeni na N.C. Khumalo khetheni khulwane ya bulasi na vhatevheli vhavho. Huno ho vha hu nyimelo i pfisaho vhutungu u i vhona.
Ho vha na mitodzi ya dakalo musi Muapostola W.Gelem na vhatevheli vhawe vha tshi humela kerekeng ngo 1997. O tanganedzwa zwi sa thivhelwi nga mbilu dzivhuya nga Vhaapostola N.V.Mlangeni na N.C.Khumalo na mirado yothe ya kereke. Nyito iyi ya tou nga yo fhodza dzimbanzhe dza tshifhinga tsho fhelaho. Muapostola W.Gelem o fhatutshedza vhukuma vhana vha Mudzimu nga pfunzo dzawe dza maanda, o vha a si na tshinwe vho fhedzi mulilo. O tamba tuwa tshitshavhani tsha u tanganya zwigwada izwo zwivhili zwa vha kereke nthihi yo tanganaho nga tshumelo dzawe dza maanda na lwa muya shangoni lothe na mashangoni a nnda. Mulaedza wawe wa u fhedzisela kha mirado ya kereke hovho na hovho he a ya maduvhani awe a u fhedzisela o vha Mateo [5.8] vha na mashudu vha mbilu dzo kunaho vhunga vha tshi do vhona Mudzimu. Muapostola W. Gelem o vha a si tsha vha muthu o takalaho nga tshenetsho tshifhinga nahone a lovha ngo 1998. Pfunzo dzawe dzi kha di tshila na namusi. "Vha na mashudu vha mbilu dzo kunaho vhunga vha tshi do vhona Mudzimu".

O vhulungwa mudi wawe ngei Tsolo Kapa Vhubvaduvha.
Muapostola Mlangeni na Muapostola Khumalo vho bvela phanda na vhuthanzi nahone mirado ya kereke namusi yo aluwa nga thukhu 300% u fanyisa na mirado maduvhani a Muapostola S.D.Phakathi ngo 1994.

Kwazulu Natal i imela phesenthe khulwane ya mirado. Mozambique na yone i na tshivhalo tshihulwane tsha mirado. Tshumelo ya u thoma ya u vhea tswayo yo farwa Angola ngo 2006. Mulavhelesi John Mthembu u ita mushumo muhulwane vhukuma mashangoni a fana na Malawi, D.R.Congo, na Angola. Kereke i khou aluwa kha eneo mashango. Muapostola Miangeni o vhea Vhaapostola vha fumi u swika namusi. Afurika Tshipembe ri na Vhaapostola J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu na E.Mzamo. Mozambique Vhaapostola Ntimbane, Mthise, Bazar na vhaapostola vho lovhaho.""";

const String _sesothoHistory = """Nalane ya The Twelve Apostles Church In Christ

1832 - Moapostola wa pele J.B. Cardale
1835 - Kereke ya Catholic Apostolic e thilwe
1852 - C.G. Klibbe o hlahile ka Tshitwe
1889 - Moapostola H.F. Niemeyer o rometse moevangeli Carl George Klibbe Afrika Borwa
1892 - Moapostola C.G. Klibbe o kgethuwe jwalo ka moapostola Kholejeng ya Baapostola Europe
1893 - Batho ba tsheletseng ba pele ba tiiswa Afrika Borwa Kapa - Lebitso la kereke e ne e le
New Apostolic Church
1913 - Karohano e qala ha Moapostola Klibbe a tswela pele ka thuto ya kgale ya kereke
ha Moapostola e Moholo Niehaus a fedisitse ofisi ya moporofeta
1926 - Lekgotla la Afrika Borwa la laela hore Moapostola Klibbe a nke lebitso le letjha la sehlopha sa hae. Lebitso e ne e le The Old Apostolic Church of Africa hobane Moapostola Klibbe o ne a batla ho latela thuto ya kgale.
1931 - Ka Motsheanong Moapostola Klibbe a hlokahala. O ne a kgethile mokgwenyana wa hae H. Velde pele a hlokahala, empa le yena o hlokahetse ka 1956 kotsing ya koloi Kimberly.
Baapostola bao Moapostola Klibbe a neng a ba kgethile e ne e le Moapostola E. Ninow, C. Ninow le W. Campbell
Moapostola wa pele e motsho e ne e le Moapostola Hlatshwayo, a latelwa ke Moapostola Ndlovu.
1972 - Moapostola S.D. Phakathi o kgethilwe ke Moapostola Ndlovu.
Ba thehile The Twelve Apostles Church of Africa.
1978 - Moapostola S.D. Phakathi o thehile The Twelve Apostles Church In Christ.
Kereke e ngodisitswe semmuso ka Lwetse 1978.

KAKARETSO YA NALANE YA THE TWELVE APOSTLES CHURCH IN CHRIST
Jwaloka Bakreste bohle re a tseba hore Jesu Kreste ke Morena, le hore o na le matla a modimo. Mattheo o re "matla ohle a filwe yena lehodimong le lefatsheng." [ Mat.28.18.] Ntate o beile tsohle matsohong a hae.[Joh.3.35. ] Matla a hae o a filwe ke Ntate lehodimong. [ Luk. 10.22.]

A re hopoleng hore Jesu o ne a tseba hore a ke ke a dula lefatsheng ka ho sa feleng. Re ithuta dithutong tsa hae hore na o ne a batla hore tshebeletso ya hae e tswele pele jwang lefatsheng. O kgethile banna ba leshome le metso e mmedi mme a ba bitsa Baapostola ba hae. Hore ba tle ba etelle kereke pele ka matla, Jesu o ba file karolo ya matla a hae.
Jesu o re Baapostola ba rometswe jwalokaha Ntate a mo rometse. [ Joh. 20.21 ]. Ba lokela ho bua nnete ka matla a tshwanang le ao Jesu a neng a na le wona, hobane Jesu o re mang kapa mang ya ba mamelang o mamela Yena. [ Luk.10.16. ]
Ho Joh.20.23. o ba fa matla a hae ho tshwarela dibe. Jesu o tlameha a be a ne a batla hore tshebeletso ya hae e tswele pele hobane ho Mattheo 28.20 o tshepisa ho ba le baapostola ho fihlela qetellong ya nako. Ebe ka mora moo evangeling ya Johane o tshepisa Moya o Halalelang ho thusa ka mosebetsi wa ho utlwisisa Nnete, [ Joh 16.13. ] mme o re Moya o Halalelang o tla dula le Baapostola kamehla. [Joh 14.16. ]
Tshebeletso ena e tlisitswe ho rona mona Afrika Borwa ke Moevangeli Carl Geog Klibbe ka 1889. O ne a rometswe ke Moapostola H.F.Niemeyer ho tswa Queensland Australia. Kaha Moevangeli Klibbe o ne a itshetlehile temong ho iphedisa, ha a fihla Kapa ka 1889 o ile a reka polasi e nyenyane Bellvile, empa hamorao a fallela Worcester hobane o ne a bua Sejeremane feela. O qalile tshebeletso ya hae ka ho tsepamisa maikutlo haholo setjhabeng se buang Sejeremane.
Bopaki ba hae bo qalile ho beha ditholwana ka 1892 ha phutheho e nyenyane e ne e thehwa Afrika Borwa kgetlo la pele. Ka 1901 moetsi wa dieta ya bitswang George Heinrich Schlaphoff le lelapa la hae, bao le bona e neng e le bajaki ba tswang Jeremane, ba etela phutheho. Schlaphoff o ile a kgahlwa haholo ke bopaki mme kapele a amohelwa le lelapa la hae. Ba tiisitswe ke Moapostola Carl Klibbe ka Pentekonta 1902. Morabo rona Schlaphoff o ile a etsa kgahlamelo e kgolo mme a ikana mosebetsing wa Morena. Hamorao o ile a fallela Kapa ho phatlalatsa Lentswe koo.
Ditshebeletso tsa Modimo tse neng di tshwarelwa phaposing ya Moevangeli Schlaphoff di ne di fumanwa haholo. Mona Holo ya pele ya Kereke e ile ya hahwa mme ya nehelwa ke Moapostola Klibbe ka Pentekonta, 4 Phuptjane 1906.
Karohano e bohloko pakeng tsa Moapostola Klibbe le Moevangeli Schlaphoff e qalile Kapa ka 1910. Lebaka le tobileng la sena le ntse le hara mofere-fere. Sena se ile sa tswela pele ho fihlela ho eba le karohano hara ditho tsa kereke. Boemo bo ile ba mpefala ka mora hore Schlaphoff a kgethwe ho ba Moapostola Jeremane, mme ho ne ho ena le dihlopha tse pedi kerekeng. Pherekano ena le kgohlano e babang e rarolotswe nyeoeng ya lekgotla ka la 26 Tshitwe 1926. Qeto ya lekgotla e bile hore Moapostola Klibbe o lokela ho tswela pele ka mesebetsi ya hae jwaloka "The Old Apostolic Church" mme Moapostola Schlaphoff a boloka lebitso la "The New Apostolic Church".
Moapostola Klibbe o ile a tswela pele ka tshebeletso ya hae jwaloka "The Old Apostolic Church" mme kereke e ile ya pholosa meya e mengata. Sena se ile sa etsa hore ho be bohlokwa hore Morena a mo hlohonolofatse ka Baapostola ba eketsehileng ho fihlela matsatsing a Moapostola F.W.Nino. Moapostola Nino le yena o kentse letsoho kgolong ya kereke ho fihlela e ena le palo e kgolo ya balatedi ba batsho. Moapostola Nino o kgethile Moapostola oa Pele ea Motsho ka 1953 ka lebitso la Samuel Hlatshwayo. Moapostola Hlatshwayo o ile a hlokahala ka 1961 mme Moapostola Nino a kgetha Moapostola J.S.Ndlovu.
Kamora lefu la Moapostola Nino kamano pakeng tsa Moapostola J.S.Ndlovu le basebetsi mmoho le yena ba basweu e ile ya senyeha. Lebaka le leholo la sena e ne e le boemo ba sepolotiki ba Afrika Borwa ka nako eo e leng "Khethollo", e ileng ya baka karohano kerekeng ka 1968. Moapostola J.S.Ndlovu o ile a dula a kgutsitse hae ka nakoana. Tshehetso eo a neng a ena le yona e ne e le makatsang. Batshehetsi ba hae ba ile ba ya hae ka bongata ho mo kgothaletsa ho tswela pele ka mosebetsi wa hae o motle. O ile a tswela pele ka tlasa lebitso le letjha 'The Twelve Apostles Church in Africa'. A tseba hantle hore ha a na monyetla kgahlanong le bahanyetsi ba hae ba basweu, Moapostola Ndlovu o ile a etsa qeto ya hore taba ena ha e na ho rarollwa lekgotleng, o ne a sa batle le ho ba mahlong a setjhaba kapa ba boholong. Ha a ka a dumella boralitaba kapa ditshwantsho tsa dikopano tsa hae tsa kereke hore di nkwe. O ne a dula a ruta balatedi ba hae hore ba se ke ba bolela mabitso a batho ba bang haholoholo Kereke ea Khale ea Baapostola (Old Apostolic Church). O kgothaleditse feela litho tsa hae ho rera Kosepele eseng letho le leng. O kopile balatedi ba hae ho siya ka kgotso diholo tsa kereke tsa Old Apostolic Church mme a ba fa mangolo a kopo ho sebedisa diphaposi tsa sekolo bakeng sa ditshebeletso tsa bona. O entse sena tlasa melawana e thata e tswang ho ba boholong. O ne a etela dikolo tseo ka sekhukhu nakong ya ditshebeletso ho etsa bonnete ba hore ba latela melao ya ba boholong. O ile a tlameha ho etsa kopo ya tumello ho tshwara dikopano tse kgolo tse bulehileng. Ditshebeletso tsa hae tse halalelang di hohetse ditho tse ngata, haholoholo metseng ya makeishene le linaheng tse kang Botswana, Swaziland le Mozambique. Dintho di ne di sa be bonolo Mozambique moo ka nako e nngwe a ileng a tlameha ho tshwara tshebeletso pela balaodi ba mmuso ba neng ba tlile ho tla bona seo a se etsang. O ile a tla Afrika Borwa a thabile haholo hobane balaodi ba mmuso Mozambique ba ne ba amme ke Moya o Halalelang mme ba mo nea tumello ya ho phatlalatsa Kosepele Mozambique. Kamora tshebeletso eo meya e mengata e ile ya pholoswa mme ya tiiswa dikarolong tse ngata tsa Mozambique. Ka Lwetse 1972 o kgethile Moapostola S.D.Phakathi Durban. Moapostola Ndlovu o kgakotse holo ya hae ya pele ya kereke Meadowlands Soweto ka 1977.
Ka 1978 Moapostola Ndlovu o ile le baemedi ba hae Mozambique bakeng sa tshebeletso ya kereke. O ne a tseba hore e ke ke ya eba leeto le bolokehileng hobane Modimo o ne a se a buile. Sena se ile sa hlaka ho bohle nakong ya tshebeletso ya ho qetela ya ho tsamaya hantle eo a ileng a e tshwarela holong ya hae e ntjha ya kereke Meadowlands. Nakong ya tshebeletso eo o ile a bua ka dintho tse neng di mo etsahletse nakong e fetileng le tse ka mo etsahallang nakong e tlang. Tshebeletso eo e ne e batla e tshwana le lepato la hae ho fapana le tsamaya hantle. E ne e le jwalo ka matsatsi a ho qetela a Jesu Kreste ha a ne a bolella Baapostola ba hae ka leeto la hae la ho ya ho Ntate wa hae lehodimong. [ Johanne 14. ] Boholo ba ba neng ba le teng mme ba utlwisisa seo Modimo a se buileng, ba ne ba ke ke ba mo dumella ho nka leeto leo hoja ba ne ba ena le kgetho. Ka tshepo ya hae ho Morena, jwaloka Morena Jesu Kreste, Moapostola Ndlovu o ne a le sebete a ya Mozambique.
Ha Moapostola Ndlovu a nka nako e telele ho feta e lebeletsoeng ho kgutla Mozambique, litho tsa kereke li ile tsa ngongoreha hobane ho ne ho se ho ngotsoe koranteng e 'ngoe ea lehae hore o ne a le mathateng le balaoli ba Mozambique.
Ha moifo wa hae o khutla Mozambique, Moapostola Ndlovu le mosali oa hae ba ne ba setse morao. Moifo o ne o e-na le litlaleho tse peli tse fapaneng mabapi le se ileng sa etsahala Mozambique. Sehlopha se seng se netefalitse tlaleho ea koranta e reng Moapostola Ndlovu o bothateng Mozambique. Sehlopha se seng se itse seo hase 'nete Moapostola Ndlovu o ne a etsa lits'ebeletso tsa ho tiisa Swaziland 'me o tla khutla haufinyane.
Sehlopha sa balebedi se ileng sa tiisa tlaleho ya koranta, e neng e eteletswe pele ke molebedi N.V.Mlangeni, ya ileng a tsamaya le Moapostola Ndlovu ho ya Mozambique a ya ho Moapostola S.D.Phakathi Durban ho tlaleha se etsahetseng Mozambique. Ha ba kgutlela Johannesburg sehlopha sa bohanyetsi se ile sa ipolela hore ba ile ba ya seba Durban, ka hona ba ile ba lelekwa kerekeng hammoho le Moapostola S.D.Phakathi. Sena se entse tsitsipano e kgolo hara ditho tsa kereke mme ba arolwa ka dihlopha tse pedi. Moapostola S.D.Phakathi o ne a se na boikgethelo haese ho sebeletsa Morena tlasa lebitso le fapaneng ho fihlela Moapostola Ndlovu a kgutla. Balatedi ba hae ba ne ba tsejwa e le "United Twelve Apostles". Dikgwedi di ile tsa feta ho se na sesupo sa Moapostola Ndlovu mme Moapostola Phakathi o ngodisitse kereke e le "The Twelve Apostles Church In Christ". Nakong eo Moapostola Ndlovu a neng a kgutlela Afrika Borwa ho ne ho le thata haholo ho kopanya dikereke tse pedi hobane kamano lipakeng tsa ditho e ne e sa ntse e le bora haholo.
Moapostola Phakathi o ile a tsoela pele ka kereke ea hae, empa a ntse a e-na le tlhompho e kholo ho Moapostola Ndlovu, o ne a ee a 'mitse Ntate. TACC e ile ea hōla ka sekhahla se tšosang haholo tlasa S.D.Phakathi hobane o ile a hlahisa mesebetsi e mengata ka kerekeng mme a tsepamisa maikutlo haholo ho batjha le ba tsofetseng. O ile a hohela batho ba lilemo tsohle kerekeng. Kaholimo ho tsohle e ne e le motho ya nang le botsoalle mme e mong le e mong o ne a mo rata haholoholo bacha, e ne e le mohale oa bona. Botho bo ile ba ata le linaheng tse ling tse kang Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi, Zambia le Botswana. Mokete wa ho qetela wa diteboho o neng o tshwaretswe lebaleng la Absa mane Durban ka Lwetse 1991, o bontshitse hore na Modimo o mo hlohonolofaditse hakaakang. Lebala la lipapali la Absa le ne le tletse mothamo o felletseng, 'me o ile a hloma Baapostola ba bahlano ka lona letsatsi leo. Mopresidente oa hona joale oa TACC N.V.Mlangeni, Motlatsi oa Mopresidente N.C. Khumalo, le Moapostola W.Gelem ba ile ba khethoa ka lona letsatsi leo. Ka lebaka la boleng bo ntseng bo hola ba ditho, Moapostola Phakathi o kgothaleditse ditho tsa hae ho reka polasi Umkomaas mane Durban ka mokhoa wa bona mme a qala kaho ea boromuoa ea kereke ya limilione tse ngata tsa li-rand Umgababa e leng ntlo-kholo ea The Twelve Apostles Church In Christ kajeno. Moapostola Phakathi o ne a e-na le maikutlo a matle ka kereke. O ne a ikemiseditse ho haha lebala mane polasing mme o itse sebopeho sa yona se tla e etsa hore ho be bonolo, hobane se se se bopilwe jwalo ka eona. Polasi e sa ntse e sebelisoa bakeng sa liketsahalo tse kholo tsa kereke kajeno. Ho hlokahala hoa Moapostola Phakathi ka la 6 Lwetse 1994 ho tlile e le tsoso ho ditho tsa kereke mme o tla dula a hopoloa. Tshebeletso ea hae ya lepato e ne e tshwaretswe polasing eo a sa tsoa e reka. Litho tse fetang 40 000 li tlile ho theola tlhompho ea ho qetela ho mohale oa bona.
E ne e le jwalo ka kotsi e habeli ho litho tsa kereke tse ntseng li tsielehile ha ho na le karohano lipakeng tsa Baapostola ba setseng, mabapi le hore na ke mang ea tla ba "HLOOHO" ea kereke. Lebitso "HLOOHO" le ile la tuma haholo mme la utlwisa dimpa tse ngata bohloko, haholoholo ba neng ba tlile kerekeng ho tla kgumamela. Kereke e ile ya arolwa ka dihlopha tse pedi. Moapostola N.V.Mlangeni o ile a kgethuwa mopresidente e motjha ke Moapostola N.C. Khumalo e neng e le mohlophisi wa kereke ka nako eo ka 1995, mme Moapostola Khumalo a le motlatsi. Ka la 29 Pulungoana 1995 lihlopha tse peli li ile tsa keteka letsatsi la tsona la liteboho polasing empa ka ho arohana. Baapostola C.Nongqunga le W.Gelem karolong e 'ngoe ea polasi le balateli ba bona mme Baapostola N.V.Mlangeni le N.C. Khumalo seterateng se seholo sa polasi le balateli ba bona. Ena e bile boemo bo bohloko haholo ho ba paki.
Ho bile le meokgo ea thabo le nyakallo ha Moapostola W.Gelem le balateli ba hae ba khutlela kerekeng ka 1997. O ile a amoheloa ntle ho maemo ka lipelo tse futhumetseng ke Baapostola N.V.Mlangeni le N.C.Khumalo mme le ditho tsohle tsa kereke. Ketso ena e ile ya bonahala e fodisa maqeba a nakong e fetileng. Moapostola W.Gelem o hlile o hlohonolofalitse bana ba Modimo ka lithuto tsa hae tse matla, o ne a se na letho haese mollo. O bapile karolo e kgolo ho kopanya dihlopha tse pedi kereke e le nngwe e kopaneng ka ditshebeletso tsa hae tse matla le tse halalelang naha ka bophara le dinaheng tse ling. Molaetsa wa hae wa ho qetela ho ditho tsa kereke hohle moo a neng a e-ya matsatsing a hae a ho qetela e ne e le Mattheo [5.8] ho lehlohonolo ba dipelo di hlwekileng hobane ba tla bona Modimo. Moapostola W. Gelem o ne a se a sa phele hantle ka nako eo mme o ile a hlokahala ka 1998. Lithuto tsa hae li ntse li phela ho fihlela kajeno. "Ho hlohonolofalitsoe ba lipelo li hloekileng hobane ba tla bona Molimo".

O epetswe lapeng la hae Tsolo kapa Botjhabela.
Moapostola Mlangeni le Moapostola Khumalo ba tsoelapele ka bopaki mme litho tsa kereke kajeno li hole bonyane 300% ha ho bapiswa le ditho nakong ea Moapostola S.D.Phakathi ka 1994.

Kwazulu Natal e emetse peresente e kholo ya botho. Mozambique le yona e na le palo e kholo ya ditho. Tshebeletso ya pele ea ho tiisa e ne e tšoaretsoe Angola ka 2006. Molebedi John Mthembu o etsa mosebetsi o makatsang dinaheng tse kang Malawi, D.R.Congo, le Angola. Kereke e ntse e gola linaheng tseo. Moapostola Miangeni o hlomile Baapostola ba leshome ho fihlela kajeno. Ka hare ho Afrika Borwa re na le Baapostola J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu le E.Mzamo. Mozambique Baapostola Ntimbane, Mthise, Bazar le baapostola ba seng ba hlokahetse.""";

const String _isiXhosaHistory =
    """Imbali ye The Twelve Apostles Church In Christ

1832 - UMpostile wokuqala u-J.B. Cardale
1835 - Kwasungulwa i-Catholic Apostolic Church
1852 - U-C.G. Klibbe wazalwa ngoDisemba
1889 - UMpostile u-H.F. Niemeyer wathumela umvangeli uCarl George Klibbe eMzantsi Afrika
1892 - UMpostile u-C.G. Klibbe wamiselwa njengompostile kwiKholeji yabaPostile eYurophu
1893 - Abantu bokuqala abathandathu batywinwa eMzantsi Afrika eKapa - Igama lecawe laliyi
New Apostolic Church
1913 - Uqhekeko lwaqala njengoko uMpostile uKlibbe waqhubeka nemfundiso endala yecawe
ngelixa uMpostile oyiNtloko uNiehaus wawuphelisa umsebenzi womprofeti.
1926 - Inkundla yaseMzantsi Afrika yagweba ukuba uMpostile uKlibbe amkele igama elitsha leqela lakhe. Igama yayiyi-The Old Apostolic Church of Africa kuba uMpostile uKlibbe wayefuna ukulandela imfundiso endala.
1931 - NgoCanzibe uMpostile Klibbe wasweleka. Wayemisele umkhwenyana wakhe uH. Velde phambi kokuba asweleke kodwa naye wasweleka ngo-1956 kwingozi yemoto eKimberly.
AbaPostile ababemiselwe nguMpostile Klibbe ibinguMpostile E. Ninow, uC. Ninow kunye noW. Campbell.
UMpostile omnyama wokuqala yaba nguMpostile Hlatshwayo, walandelwa nguMpostile Ndlovu.
1972 - UMpostile S.D. Phakathi wamiselwa nguMpostile Ndlovu.
Baqala i-The Twelve Apostles Church of Africa.
1978 - UMpostile S.D. Phakathi waseka i-The Twelve Apostles Church In Christ.
Icawe yabhaliswa ngokusesikweni ngoSeptemba wama-1978.

IMBALI EMFUTSHANE YETHE TWELVE APOSTLES CHURCH IN CHRIST
NjengamaKristu sonke siyazi ukuba uYesu Kristu uyiNkosi, kwaye unegunya lasezulwini jikelele. UMateyu uthi "lonke igunya linikwe yena ezulwini nasemhlabeni." [ Mat.28.18.] UYise wabeka yonke into ezandleni zakhe.[Yoh.3.35. ] Igunya lakhe ulinikwe nguYise ezulwini. [ Luk. 10.22.]

Masikhumbule ukuba uYesu wayesazi ukuba akanakuhlala emhlabeni ngonaphakade. Sifunda kwiimfundiso zakhe indlela abefuna ngayo ubulungiseleli bakhe buqhubeke emhlabeni. Wakhetha amadoda alishumi elinambini wawabiza ngokuba ngabaPostile bakhe. Ukuze bakhokele icawe ngamandla negunya, uYesu wabanika isabelo kowakhe umsebenzi nasegunyeni.
UYesu uthi abaPostile bathunyelwe kanye njengoko uYise emthumileyo. [ Yoh. 20.21 ]. Bamele bathethe inyaniso ngohlobo olufanayo lwegunya awayenalo uYesu, kuba uYesu uthi nabani na obaphulaphulayo uphulaphula Yena. [ Luk.10.16. ]
KuYoh.20.23. ubanika ngokukodwa igunya lakhe lokuxolela izono. UYesu umele ukuba wayenjongo yokuba ubulungiseleli bakhe buqhubeke kuba kuMateyu 28.20 uthembisa ukuba nabaPostile kude kube sekupheleni kwexesha. Emva koko kwivangeli kaYohane uthembisa uMoya oyiNgcwele ukuze ancede kumsebenzi wokuqonda iNyaniso, [ Yoh. 16.13. ] yaye uthi uMoya oyiNgcwele uya kuhlala nabaPostile ngonaphakade. [Yoh. 14.16. ]
Obu bulungiseleli baziswa kuthi eMzantsi Afrika nguMvangeli Carl Geog Klibbe ngowe-1889. Wayethunyelwe nguMpostile H.F.Niemeyer waseQueensland eOstreliya. Ekubeni uMvangeli Klibbe wayexhomekeke ekulimeni ngokuziphilisa, akufika eKapa ngowe-1889 wathenga ifama encinane eBellvile, kodwa kamva wafudukela eWorcester ngenxa yokuba wayekhuluma isiJamani kuphela. Uqale ubulungiseleli bakhe ngokugxila ikakhulu kuluntu oluthetha isiJamani.
Ubungqina bakhe baqala ukuthwala isiqhamo ngo-1892 xa ibandla lokuqala lavela eMzantsi Afrika okokuqala. Ngowe-1901 umenzi wezihlangu ogama linguGeorge Heinrich Schlaphoff kunye nosapho lwakhe, nabo ababengabafuduki basuka eJamani batyelela ibandla. USchlaphoff wachukumiseka ngokunzulu bobu bungqina kwaye kungekudala wamkelwa kunye nosapho lwakhe. Batywinwa nguMpostile uCarl Klibbe ngePentekoste ngo-1902. UMzalwan' uSchlaphoff waba nempembelelo enkulu yaye wayezinikele ngokupheleleyo emsebenzini weNkosi. Wafudukela eKapa ukuze asasaze iLizwi khona kamva.
Iinkonzo ezingcwele ezazibanjelwe kwigumbi likaMvangeli uSchlaphoff ngokukhawuleza zaya zanda. Apha iHolo yokuqala yeCawe yakhiwa kwaye yanikezelwa nguMpostile Klibbe ngePentekoste, 4 Juni 1906.
Ulwahlulo olubuhlungu phakathi kukaMpostile Klibbe kunye noMvangeli Schlaphoff lwaqala eKapa ngowe-1910. Esona sizathu soku sisaphikiswa. Oku kwaqhubeka kwada kwakho uqhekeko phakathi kwamalungu ecawe. Imeko yaba mandundu emva kokuba uSchlaphoff emiselwe njengoMpostile eJamani, yaye kwakukho amaqela amabini ecaweni. Esi sidubedube nongquzulwano olukrakra lusonjululwe kwinkundla yamatyala ngomhla wama-26 kuDisemba 1926. Isigwebo senkundla sasikukuba uMpostile uKlibbe makazalisekise iimbopheleleko zakhe njenge-"The Old Apostolic Church" ibe uMpostile uSchlaphoff wagcina igama elithi "The New Apostolic Church".
UMpostile uKlibbe waqhubeka nobulungiseleli bakhe njenge-"The Old Apostolic Church" yaye icawe yasindisa imiphefumlo emininzi. Oku kwakwenza kube yimfuneko ukuba iNkosi imsikelele ngabaPostile abangakumbi kude kube yimihla yoMpostile uF.W.Nino. UMpostile uNino naye waba negalelo ekukhuliseni icawe de yaba nenani elikhulu labalandeli abamnyama. UMpostile Nino wamisela uMpostile wokuqala oMnyama ngo-1953 egameni likaSamuel Hlatshwayo. UMpostile uHlatshwayo wasweleka ngo-1961 uMpostile Nino wamisela uMpostile J.S.Ndlovu.
Emva kokusweleka koMpostile uNino ulwalamano phakathi koMpostile J.S.Ndlovu nabalingane bakhe abamhlophe lwahla. Esona sizathu soku yayiyimeko yezopolitiko yaseMzantsi Afrika ngexesha lo"Calucalulo", okwakhokelela kuqhekeko ecaweni ngowe-1968. UMpostile J.S.Ndlovu wahlala exolile ekhayeni lakhe ixeshana. Inkxaso awayenayo yayimangalisa. Abalandeli bakhe baya kowabo ngobuninzi babo bemkhuthaza ukuba aqhubeke nomsebenzi wakhe omhle. Wawuqhubela phambili phantsi kwegama elitsha 'The Twelve Apostles Church in Africa'. . Ekwazi kakuhle ukuba akanathuba nenkcaso yakhe emhlophe, uMpostile Ndlovu wagqiba ukuba lo mbandela awuyi kusonjululwa enkundleni, engathandi kwanokuba semehlweni oluntu okanye abasemagunyeni. Zange avumele nawaphi na amajelo eendaba okanye nayiphi na imifanekiso yeentlanganiso zecawe yakhe zithatyathwe. Wayesoloko efundisa abalandeli bakhe ukuba bangawakhankanyi amagama abanye abantu ngakumbi iCawa yeOld Apostolic. Wakhuthaza amalungu akhe kuphela ukuba ashumayele ivangeli kungabikho nto yimbi. Wacela abalandeli bakhe ukuba bazishiye ngoxolo iiholo zecawe ye-Old Apostolic Church kwaye wabanika iileta zesicelo ukuba basebenzise amagumbi okufundela ezikolo iinkonzo zabo. Oku wakwenza phantsi kwemithetho engqongqo yabasemagunyeni. Wayehambela ngokufihlakeleyo ezo zikolo ngexesha leenkonzo aqinisekise ukuba bayayithobela imithetho yabasemagunyeni. Kuye kwafuneka afake isicelo semvume yokubamba iindibano ezinkulu zikawonke-wonke. Iinkonzo zakhe zobuthixo zatsala amalungu amaninzi, ngakumbi kwiilokishi nakumazwe afana neBotswana, iSwaziland kunye neMozambique. Izinto zazingelula eMozambique ngohlobo lokuba wathi ngelinye ixesha wenze inkonzo phambi kwamagosa karhulumente abeze kuzobona lento ayenzayo. Weza eMzantsi Afrika evuye kakhulu kuba amagosa kaRhulumente waseMozambique ayeshukunyiswe nguMoya oyiNgcwele amnceda ngemvume yokusasaza ivangeli eMozambique. Emva kwaloo nkonzo imiphefumlo emininzi yasindiswa kwaye yatywinwa kwiindawo ezininzi zaseMozambique. NgoSeptemba 1972 wamisela uMpostile S.D.Phakathi eThekwini. UMpostile Ndlovu wanikezela ngesakhiwo sakhe sokuqala secawe eMeadowlands eSoweto ngowe-1977.
Ngo-1978 uMpostile uNdlovu wahamba negqiza lakhe besiya eMozambique kwinkonzo yecawe. Wayesazi ukuba yayingazuba luhambo olukhuselekileyo kuba uThixo wayeselethethile. Oku kwacaca kumntu wonke ngethuba lenkonzo yokugqibela yokuvalelisa awayibamba kwiholo yakhe entsha yecawe eMeadowlands. Ngethuba laloo nkonzo wayethetha ngezinto ezazimhlele exesheni kwaye nangezinto ezinokumehlela kwixesha elizayo. Loo nkonzo yayifana nomngcwabo wakhe kunendlela-ntle. Kwakunjengemihla yokugqibela kaYesu Krestu xa wayexelela abaPostile bakhe ngohambo lwakhe lokuya kuYise ezulwini. [ Yohane 14. ] Uninzi lwabo babekho baza bayiqonda into uThixo ayithethileyo, babe ngasayi kumvumela aluthathe olo hambo ukuba babenokuzikhethela. Ngethemba lakhe eNkosini, njengeNkosi uYesu Kristu UMpostile Ndlovu wayekhaliphile waqhubeka ukuya eMozambique.
Xa uMpostile Ndlovu ethatha ixesha elide kunokulindelwa ukuba abuye eMozambique, amalungu ecawe amaxhala kuba kwakusele kuxeliwe kwelinye lamaphephandaba asekuhlaleni ukuba usengxakini nabasemagunyeni eMozambique.
Xa abathunywa bakhe babebuya eMozambique, uMpostile Ndlovu nomkakhe bashiywa. Abathunywa bafumana iingxelo ezimbini ezingafaniyo malunga nokwenzekayo eMozambique. Elinye iqela layiqinisekisa ingxelo yephephandaba yokuba uMpostile uNdlovu usengxakini eMozambique. Elinye iqela lathi asiyonyani uMpostile Ndlovu uqhuba iinkonzo zokutywina eSwaziland kwaye uya kubuya kungekudala.
Iqela labaveleli elaqinisekisa ingxelo yephephandaba, likhokelwa ngumveleli uN.V.Mlangeni, owayekhaphe uMpostile Ndlovu eMozambique, laya kuMpostile S.D.Phakathi eThekwini liyokuxela okwenzekileyo eMozambique. Ekubuyeni kwabo eRhawutini iqela elichasayo lathi bebehambe besiya kuhleba eThekwini, kungoko begxothiwe ecaweni kunye noMpostile S.D.Phakathi. Oku kuye kwadala uxinezeleko olukhulu phakathi kwamalungu ecawe baze bohlulwa bangamaqela amabini. UMpostile uS.D.Phakathi wayengenandlela yimbi ngaphandle kokukhonza iNkosi phantsi kwegama elahlukileyo kude kubuye uMpostile Ndlovu. Abalandeli bakhe babesaziwa ngokuba yi-"United Twelve Apostles". Iinyanga zidlulile kungekho luphawu loMpostile uNdlovu kwaye uMpostile Phakathi wayibhalisa icawe njenge-"The Twelve Apostles Church In Christ". Ngexesha apho uMpostile Ndlovu abuyela ngalo eMzantsi Afrika kwakunzima kakhulu ukudibanisa ezi cawe zimbini kuba ulwalamano phakathi kwamalungu lwalusebutshaba kakhulu.
UMpostile Phakathi waqhubeka necawe yakhe, kodwa wayesamhlonela kakhulu uMpostile Ndlovu, wayemdlisela, embiza uYise. I-TACC ikhule ngesantya esoyikekayo phantsi kuka-S.D.Phakathi kuba yazisa izinto ezininzi ecaweni kwaye ijolise ngakumbi kulutsha kunye nabantu abadala. Watsala abantu bayo yonke iminyaka ecaweni. Ngaphezu kwako konke wabe engumntu onobuhlobo kwaye wonke umntu ebemthanda ingakumbi ulutsha, ubeligorha labo. Amalungu akhula nakwamanye amazwe afana neZimbabwe, iSwaziland, iLesotho, iMozambique, D.R.Congo, iMalawi, iZambia kunye neBotswana. Umsitho wokugqibela wokubulela owawubanjelwe kwibala lemidlalo lase-Absa eThekwini ngoSeptemba 1991, ubonise ukuba uThixo ubemsikelele kangakanani. Ibala lemidlalo lase-Absa lalizele liphuphuma, waze wamisela abapostile abahlanu ngaloo mini. UMongameli okhoyo weTACC uN.V.Mlangeni, uSekela Mongameli N.C. Khumalo, kunye noMpostile W.Gelem bamiswa ngaloo mini. Ngenxa yokukhula kwamalungu, uMpostile Phakathi ukhuthaze amalungu akhe ukuba athenge ifama eMkhomaas eThekwini ngemali yabo, waqalisa nokwakhiwa kwecawa exabisa izigidi zeerandi eMgababa eyikhomkhulu le-The Twelve Apostles Church in Christ namhlanje. UMpostile Phakathi wayeneembono ezinkulu ngecawa. Ebenezicwangciso zokwakha ibala kule fama yaye ebesithi ukuma kwayo kuzakukwenza kube lula kuba sele imile njengalo. Le fama isasetyenziselwa imisitho emikhulu yecawe nanamhlanje. Ukusweleka kukaMpostile Phakathi nge-6 kaSeptemba ngo-1994 kwafika ngamandla ebandleni yaye uya kuhlala ekhunjulwa. Inkonzo yakhe yomngcwabo ibibanjelwe efameni abesanda kuyithenga. Amalungu angaphezu kwama-40 000 eza kunika imbeko yawo yokugqibela kwiqhawe lawo.
Kwakufana nesibetho esiphindwe kabini kumalungu ecawa asele exunguphele ukuba kubekho iyantlukwano phakathi kwabaPostile ababeseleyo, malunga nokuba ngubani na oza kuba yi "NTLOKO" yecawe. Igama elithi "INTLOKO" laduma kakhulu kwaye laphazamisa iizisu zabaninzi, ingakumbi abo abeza ecaweni ukuza kukhonza. Icawe yaqhekeka yaba ngamaqela amabini. UMpostile N.V.Mlangeni wonyulwa uMongameli omtsha nguMpostile N.C. Khumalo owayengumnxibelelanisi wecawa ngelo xesha ngowe-1995, yaye uMpostile uKhumalo waba lisekela. Ngomhla wama-29 kweyeNkanga 1995 amaqela amabini abhiyozela usuku lwawo lokubulela efameni kodwa ngokwahlukana. Abapostile uC.Nongqunga noW.Gelem kwelinye icala lefama kunye nabalandeli babo nabaPostile uN.V.Mlangeni noN.C. Khumalo kwibala elikhulu lefama. Le yayiyimeko edabukisayo kakhulu ukuyibona.
Kwakukho iinyembezi zovuyo nolonwabo ukubuyela koMpostile W.Gelem nabalandeli bakhe ecaweni ngowe-1997. Wulwe emangweni ngokungenamiqathango ziintliziyo ezifudumeleyo zabaPostile uN.V.Mlangeni noN.C.Khumalo namalungu onke ecawa. Esi senzo sabonakala ngathi siyawaphilisa amanxeba exesha elidlulileyo. UMpostile uW.Gelem wabasikelela ngenene abantwana bakaThixo ngemfundiso yakhe enamandla, wayengenanto ngaphandle komlilo. Waba negalelo elikhulu ekuhlanganiseni lawa maqela mabini abeyicawa enye emanyeneyo kunye neenkonzo zakhe ezinamandla nezobuthixo kulo lonke ilizwe naphesheya. Umyalezo wakhe wokugqibela kumalungu ecawa naphi na apho ayeya khona ngeentsuku zakhe zokugqibela nguMateyu [5.8] banoyolo abahlambulukileyo intliziyo kuba baya kumbona uThixo. UMpostile W. Gelem wayengaselilo indoda enempilo ngelo xesha yaye wasweleka ngo-1998. Iimfundiso zakhe zisaphila unanamhla. "Banoyolo abahlambulukileyo intliziyo kuba baya kumbona uThixo".

Wangcwatywa eyadini yakubo eTsolo kwiphondo leMpuma Koloni.
UMpostile Mlangeni noMpostile Khumalo baqhubeka nobungqina kwaye namhlanje amalungu ecawa akhule ngama-300% ukuthelekisa namalungu angeentsuku zikaMpostile S.D.Phakathi ngo-1994.

IKwazulu Natal imele ipesenti enkulu yobulungu. IMozambique ikwanenani elikhulu lamalungu.Inkonzo yokutywina yokuqala yabanjelwa e-Angola ngo-2006. UMveleli uJohn Mthembu wenza umsebenzi oncomekayo kumazwe afana neMalawi, iD.R.Congo, ne-Angola. ICawa iyakhula kula mazwe. UMpostile Miangeni umisele abaPostile abalishumi de kube namhlanje. EMzantsi Afrika sinabaPostile uJ.E.Hlongwane, uJ.R.Magano, uD.S.Msane,S.D.Ndlovu noE.Mzamo. EMozambique Abapostile uNtimbane, uMthise, uBazar nabaPostile abangasekhoyo.""";

const String _isiZuluHistory =
    """Umlando we The Twelve Apostles Church In Christ

1832 - Umphostoli wokuqala u-J.B. Cardale
1835 - Kwasungulwa i-Catholic Apostolic Church
1852 - U-C.G. Klibbe wazalwa ngoZibandlela
1889 - Umphostoli u-H.F. Niemeyer wathumela umvangeli uCarl George Klibbe eNingizimu Afrika
1892 - Umphostoli u-C.G. Klibbe wamiswa njengomphostoli eKolishi labaPhostoli eYurophu
1893 - Abantu bokuqala abayisithupha babekwa uphawu eNingizimu Afrika eKapa - Igama lebandla lalithi
New Apostolic Church
1913 - Uqhekeko lwaqala njengoba uMphostoli Klibbe aqhubeka nemfundiso endala yebandla
ngenkathi uMphostoli Omkhulu uNiehaus ehlakaza ihhovisi lomprofethi
1926 - Inkantolo yaseNingizimu Afrika yakhipha isinqumo sokuthi uMphostoli Klibbe kufanele athathe igama elisha leqembu lakhe. Igama kwakuyi-The Old Apostolic Church of Africa ngoba uMphostoli Klibbe wayefuna ukulandela imfundiso endala.
1931 - NgoNhlaba, uMphostoli Klibbe washona. Wayemise umkhwenyana wakhe uH. Velde ngaphambi kokuba ashone, kodwa naye washona ngo-1956 engozini yemoto eKimberly.
AbaPhostoli ababemisiwe nguMphostoli Klibbe kwakunguMphostoli E. Ninow, C. Ninow no-W. Campbell
Umphostoli wokuqala omnyama kwaba uMphostoli Hlatshwayo, walandelwa uMphostoli Ndlovu.
1972 - Umphostoli S.D. Phakathi wamiswa uMphostoli Ndlovu.
Basungula i-The Twelve Apostles Church of Africa.
1978 - Umphostoli S.D. Phakathi wasungula i-The Twelve Apostles Church In Christ.
Ibandla labhaliswa ngokusemthethweni ngoMandulo 1978.

UMLANDO OMFUSHANE WE THE TWELVE APOSTLES CHURCH IN CHRIST
NjengamaKristu sonke siyazi ukuthi uJesu Kristu uyiNkosi, futhi unamandla onke asezulwini nasemhlabeni. UMathewu uthi "Nginikiwe amandla onke ezulwini nasemhlabeni." [ Math.28.18.] UBaba wabeka konke ezandleni zakhe.[Joh.3.35. ] Amandla akhe uwanikwe nguBaba ezulwini. [ Luk. 10.22.]

Masikhumbule ukuthi uJesu wayazi ukuthi wayengeke ahlale emhlabeni kuze kube phakade. Sifunda ezimfundisweni zakhe ukuthi wayehlose ukuthi inkonzo yakhe iqhubeke kanjani emhlabeni. Wakhetha amadoda ayishumi nambili wawawabiza ngabaPhostoli bakhe. Ukuze bahole ibandla ngamandla negunya uJesu wabanika isabelo kowakhe amandla aphezulu.
UJesu uthi abaPhostoli bathunyiwe njengoba nje noBaba amthuma. [ Joh. 20.21 ]. Bamele bakhulume iqiniso ngohlobo olufanayo lwegunya uJesu ayenalo, ngoba uJesu uthi onilalelayo nina ulalela Yena. [ Luk.10.16. ]
KuJoh.20.23. ubanika ngokuqondile igunya lakhe lokuthethelela izono. Kumelwe ukuba uJesu wayehlose ukuba inkonzo yakhe iqhubeke ngoba kuMathewu 28.20 uthembisa ukuba nabaPhostoli kuze kube sekupheleni kwesikhathi. Ngemva kwalokho evangeli likaJohane uthembisa uMoya oNgcwele ukuze asize emsebenzini wokuqonda Iqiniso, [ Joh 16.13. ] futhi uthi uMoya oNgcwele uyohlala nabaPhostoli kuze kube phakade. [Joh 14.16. ]
Le nkonzo yalethwa kithina eNingizimu Afrika nguMvangeli Carl Geog Klibbe ngo-1889. Wayethunywe nguMphostoli H.F.Niemeyer waseQueensland e-Australia. Njengoba uMvangeli Klibbe ayethembele kwezolimo ukuze aziphilise, ngesikhathi efika eKapa ngo-1889 wathenga ipulazi elincane eBellvile, kodwa kamuva wathuthela eWorcester ngoba wayekwazi ukukhuluma isiJalimane kuphela. Waqala inkonzo yakhe ngokugxila kakhulu emphakathini okhuluma isiJalimane.
Ubufakazi bakhe baqala ukuthela izithelo ngo-1892 ngesikhathi ibandla lokuqala livela eNingizimu Afrika okokuqala ngqa. Ngo-1901 umkhandi wezicathulo ogama lakhe linguGeorge Heinrich Schlaphoff kanye nomndeni wakhe, nabo ababefuduke eJalimane bavakashela ibandla. USchlaphoff wahlatshwa umxhwele kakhulu yibufakazi futhi ngokushesha yena nomndeni wakhe bamukelwa. Babekwa uphawu nguMphostoli uCarl Klibbe ngePhentekoste ngo-1902. UMzalwane uSchlaphoff waba negalelo elikhulu futhi wayezinikele kakhulu emsebenzini weNkosi. Wabe esethuthela eKapa ukuyoqhubeza iZwi khona.
Izinkonzo ezingcwele ezazibanjelwe egumbini likaMvangeli uSchlaphoff zasheshe zandisa inani labantu. Lapha kwakhiwa iHholo LeSonto lokuqala elanikezelwa nguMphostoli Klibbe ngePhentekoste, ngoJuni 4, 1906.
Uqhekeko oludabukisayo phakathi kukaMphostoli Klibbe kanye noMvangeli Schlaphoff lwaqala eKapa ngo-1910. Isizathu esiqondile salokhu kusaxoxiswana ngaso. Lokhu kwaqhubeka kwaze kwaba nokwehlukana phakathi kwamalungu ebandla. Isimo saba sibi kakhulu ngemuva kokuthi uSchlaphoff egcotshwe njengoMphostoli eJalimane, futhi kwaba namaqembu amabili ebandleni. Lokhu kuxokozela nengxabano ebuhlungu kwaxazululwa eNkantolo ngo-26 Disemba 1926. Isinqumo senkantolo kwaba ukuthi uMphostoli Klibbe uzoqhubeka nemisebenzi yakhe njenge-"The Old Apostolic Church" kuthi uMphostoli Schlaphoff agcine igama elithi "The New Apostolic Church".
UMphostoli Klibbe waqhubeka nenkonzo yakhe njenge-"The Old Apostolic Church" kanti leli bandla lasindisa imiphefumulo eminingi. Lokhu kwenza kwaba nesidingo sokuthi iNkosi imbusise ngabaPhostoli abaningi kuze kube sezinsukwini zikaMphostoli F.W.Nino. UMphostoli uNino naye waba negalelo ekukhuleni kwebandla kwaze kwaba nabalandeli abaningi abamnyama. UMphostoli uNino wagcoba uMphostoli wokuqala omnyama ngo-1953 egameni likaSamuel Hlatshwayo. UMphostoli Hlatshwayo washona ngo-1961 kanti uMphostoli uNino wagcoba uMphostoli J.S.Ndlovu.
Ngemuva kokushona kukaMphostoli Nino ubudlelwano phakathi kukaMphostoli J.S.Ndlovu nabalingani bakhe abamhlophe buba bubi. Isizathu esikhulu salokhu kwakuyisimo sezombangazwe saseNingizimu Afrika ngaleso sikhathi so-"Bandlululo", esaholela ekuqhekekeni kwebandla ngo-1968. UMphostoli J.S.Ndlovu wahlala ethule ekhaya lakhe isikhathi esithile. Ukwesekwa ayenakho kwakumangalisa. Abalandeli bakhe baya kwakhe ngobuningi babo bezomkhuthaza ukuthi aqhubeke nomsebenzi wakhe omuhle. Waqhubeka negama elisha 'The Twelve Apostles Church in Africa'. Azi kahle kamhlophe ukuthi wayengenalo ithuba kubaphikisi bakhe abamhlophe, uMphostoli Ndlovu wanquma ukuthi lolu daba aluzuxazululwa enkantolo, wayengafuni ngisho ukuba semehlweni omphakathi noma eziphathimandla. Akenzanga noma iyiphi imidiya noma izithombe zemihlangano yakhe yebandla zithathwe. Wayelokhu efundisa abalandeli bakhe ukuba bangawasho amagama abanye abantu ikakhulukazi iThe Old Apostolic Church. Wakhuthaza kuphela amalungu akhe ukuba ashumayele ivangeli futhi kungekho okunye. Wacela abalandeli bakhe ukuba bawashiye ngokuthula amahholo ebandla lama-Old Apostolic Church wabanika izincwadi ezicele ukuba basebenzise amagumbi okufundela ezikole emisebenzini yabo. Ukwenze lokhu ngaphansi kwemithetho eqinile evela kuziphathimandla. Wayevakashela lezo zikole ngokuyimfihlo ngezikhathi zezinkonzo ukuze enze isiqiniseko sokuthi bathobela imithetho yeziphathimandla. Kwadingeka acele imvume yokubamba imihlangano evulekile emikhulu. Izinkonzo zakhe zobuNkulunkulu zihehe amalungu amaningi, ikakhulukazi emalokishini nasemazweni afana neBotswana, iSwaziland kanye neMozambique. Izinto zazingelula eMozambique ngendlela yokuthi ngesinye isikhathi kwadingeka ukuthi enze inkonzo phambi kwezikhulu zikahulumeni ezaziye kuzobona ayekwenza. Weza eNingizimu Afrika ejabule kakhulu ngenxa yokuthi izikhulu zikahulumeni waseMozambique zazithintwe nguMoya oNgcwele zamnika imvume yokusabalalisa ivangeli eMozambique. Ngemva kwaleyo nkonzo kwasindiswa imiphefumulo eminingi yabekwa uphawu ezingxenyeni eziningi zaseMozambique. NgoSepthemba 1972 wagcoba uMphostoli S.D.Phakathi eThekwini. UMphostoli Ndlovu wanikezela ihholo lakhe lokuqala lebandla eMeadowlands eSoweto ngo-1977.
Ngo-1978 uMphostoli Ndlovu wahamba nethimba lakhe baya eMozambique enkonzweni yebandla. Wayazi ukuthi kwakungeke kube uhambo oluphephile ngoba uNkulunkulu wayesekhulumile. Lokhu kwacaca kuwo wonke umuntu ngesikhathi inkonzo yokuvalelisa ayenze ehholo lakhe elisha lebandla eMeadowlands. Phakathi naleyo nkonzo wakhuluma ngezinto ezazimenze esikhathini esedlule kanye nezinto ezingase zimehlele esikhathini esizayo. Leyo nkonzo yayifana kakhulu nomngcwabo wakhe kunokuvalelisa. Kwakufana nezinsuku zokugcina zikaJesu Kristu ngenkathi etshela abaPhostoli bakhe ngohambo lwakhe oluya kuYise osezulwini. [ Johane 14. ] Abaningi balabo ababekhona futhi baqonda uNkulunkulu ayekushilo, babengeke bamvumele ukuba athathe lolo hambo ukuba babenokuzikhethela. Ngethemba lakhe eNkosini, njengeNkosi uJesu Kristu UMphostoli Ndlovu waba nesibindi futhi waya eMozambique.
Lapho uMphostoli Ndlovu ethatha isikhathi eside kunalokho obekulindelwe ukubuya eMozambique, amalungu ebandla aqala ukukhathazeka ngoba kwase kubikiwe kwelinye lamaphephandaba endawo ukuthi usesenkingeni nezikhulu zaseMozambique.
Ngesikhathi ithimba lakhe libuya eMozambique, uMphostoli Ndlovu nomkakhe basalela ngemuva. Ithimba lalinemibiko emibili engafani mayelana nokwenzeka eMozambique. Elinye iqembu laqinisekisa umbiko wephephandaba wokuthi uMphostoli Ndlovu usesenkingeni eMozambique. Elinye iqembu lathi akulona iqiniso uMphostoli Ndlovu wenza izinkonzo zokubekwa uphawu eSwaziland kwaye uzobuya maduze.
Ithimba lababonisi elaqinisekisa lo mbiko wephephandaba liholwa umbonisi uN.V.Mlangeni, owaphelezela uMphostoli Ndlovu waya eMozambique laya kuMphostoli S.D.Phakathi eThekwini ukuyobika ngokwenzeka eMozambique. Ekubuyeni kwabo eGoli iqembu eliphikisayo lathi babehambe beyohleba eThekwini, ngakho bakhishwa ebandleni kanye noMphostoli S.D.Phakathi. Lokhu kwadala ukungezwani okukhulu kwamalungu ebandla futhi ahlukana aba ngamaqembu amabili. UMphostoli S.D.Phakathi wayengenakho okunye ayengakhetha ngaphandle kokusebenzela iNkosi ngaphansi kwegama elihlukile kwaze kwabuya uMphostoli Ndlovu. Abalandeli bakhe baziwa ngokuthi "United Twelve Apostles". Izinyanga zadlula kungelona uphawu lukaMphostoli Ndlovu kanti uMphostoli Phakathi wabhalisa leli bandla ngokuthi "The Twelve Apostles Church In Christ". Ngesikhathi uMphostoli Ndlovu ebuyela eNingizimu Afrika kwakunzima kakhulu ukuhlanganisa la mabandla amabili njengoba ubudlelwane bamalungu babusengobobutha kakhulu.
UMphostoli Phakathi waqhubeka nebandla lakhe, kodwa wayesamhlonipha kakhulu uMphostoli Ndlovu, wayemkhonzile embiza ngoBaba wakhe. I-TACC ikhule ngesivinini esikhulu ngaphansi kuka-S.D.Phakathi ngoba wethula imisebenzi eminingi ebandleni wagxila kakhulu kusha kanye nakwasebekhulile. Uhehe abantu babobonke ubudala esontweni. Ngaphezu kwakho konke ubengumuntu onobungane kakhulu futhi wonke umuntu ubemthanda ikakhulukazi abasha, ubeyiqhawe labo. Amalungu akhula kwamanye amazwe afana neZimbabwe, iSwaziland, iLesotho, iMozambique, iD.R.Congo, iMalawi, iZambia kanye neBotswana. Umkhosi wokugcina wokubonga owawuse-Absa Stadium eThekwini ngoSepthemba 1991, wakhombisa ukuthi uNkulunkulu umbusise kangakanani. Inkundla yezemidlalo i-Absa yayigcwele phama, waze wagcoba abaPhostoli abahlanu ngalolo suku. UMongameli wamanje we-TACC uN.V.Mlangeni, iPhini likaMongameli uN.C. Khumalo, kanti uMphostoli W.Gelem nabo bagcotshwa ngalolo suku. Ngenxa yokukhula kwamalungu, uMphostoli Phakathi wakhuthaza amalungu akhe ukuthi athenge ipulazi eMkhomaas eThekwini ngezimali zawo uqobo kanti waqala ukwakhiwa kwebandla elibiza izigidi zamarandi eMgababa okuyihhovisi elikhulu le-The Twelve Apostles Church In Christ namuhla. UMphostoli Phakathi wayenemibono emikhulu ngebandla. Ube nezinhlelo zokwakha inkundla epulazini wathi isimo salo sizoyenza ibe lula ngoba sekushiwo njengayo. Leli pulazi lisasetshenziselwa imicimbi emikhulu yebandla nanamuhla. Ukudlula emhlabeni kukaMphostoli Phakathi mhla ziyisi-6 kuMandulo ngo-1994 kwafika ngokushaqisa amalungu ebandla kanti uyohlala ekhunjulwa njalo. Inkonzo yomngcwabo wakhe ibibanjelwe epulazini abesanda kulithenga. Amalungu angaphezu kwama-40 000 afika ezozokhokha imbeko yawo yokugcina eqhaweni labo.
Kwakufana neshwa eliphindwe kabili kumalungu ebandla ayesekhathazekile njengoba kwaba noqhekeko phakathi kwabaPhostoli ababesasele, mayelana nokuthi ngubani ozoba yisi-"NHLOko" yebandla. Igama elithi "INHLOKO" laduma kakhulu futhi laphazamisa izisu zabaningi, ikakhulukazi labo abeza ebandleni ukuzokhuleka. Ibandla lahlukana phakathi kwaba amaqembu amabili. UMphostoli N.V.Mlangeni wakhethwa njengomongameli omusha nguMphostoli N.C. Khumalo owayengumxhumanisi webandla ngaleso sikhathi ngo-1995, kanti uMphostoli Khumalo waba yiphini. Ngomhlaka-29 kuLwezi ngo-1995 lawa maqembu womabili agubha usuku lwawo lokubonga epulazini kodwa ngokwahlukana. AbaPhostoli C.Nongqunga noW.Gelem kwelinye icala lepulazi kanye nabalandeli babo kanye nabaPhostoli N.V.Mlangeni noN.C. Khumalo enkundleni enkulu yepulazi kanti balandeli babo. Lesi kwakuyisimo esidabukisa kakhulu ukusibona.
Kwaba nezinyembezi zenjabulo nenjabulo ngenkathi uMphostoli W.Gelem nabalandeli bakhe bebuyela ebandleni ngo-1997. Wamukelwa ngaphandle kwemibandela ngezinhliziyo ezifudumele nguMphostoli N.V.Mlangeni kanye noN.C.Khumalo kanye nawo wonke amalungu ebandla. Lesi senzo sasibonakala selapha amanxeba esikhathi esidlule. UMphostoli W.Gelem wababusisa ngempela abantwana bakaNkulunkulu ngezimfundiso zakhe ezinamandla, wayengenalutho ngaphandle komlilo. Wabamba iqhaza elikhulu ekuhlanganiseni la maqembu womabili ebandla elilodwa elibumbene nezinkonzo zakhe ezinamandla nezobuNkulunkulu ezweni lonke naphesheya. Umyalezo wakhe wokugcina kumalungu ebandla nomakuphi lapho ayehamba khona ngezinsuku zakhe zokugcina kwakuMathewu [5.8] babusisiwe abanenhliziyo ehlanzekile ngoba bayombona uNkulunkulu. UMphostoli W. Gelem wayengasengumuntu ophile kahle ngaleso sikhathi futhi washona ngo-1998. Izimfundiso zakhe zisaphila nanamuhla. "Babusisiwe abanenhliziyo ehlanzekile ngoba bayobona uNkulunkulu".

Wangcwatshwa egcekeni lakubo eTsolo eMpumalanga Kapa.
UMphostoli Mlangeni kanye noMphostoli Khumalo baqhubeka nobufakazi kanti ubulungu bebandla namuhla sebudlondlobale okungenani ngama-300% uma kuqhathaniswa nobulungu ngezinsuku zikaMphostoli S.D.Phakathi ngo-1994.

IKwazulu Natal imele iphesenti elikhulu lobulungu. IMozambique nayo inesibalo esikhulu samalungu.Inkonzo yokuqala yokubekwa uphawu yabanjelwa e-Angola ngo-2006. UMbonisi uJohn Mthembu wenza umsebenzi oncomekayo kakhulu emazweni afana neMalawi, i-D.R.Congo, kanye ne-Angola. Ibandla liyakhula kulawo mazwe. UMphostoli Miangeni umise abaPhostoli abayishumi kuze kube namuhla. ENingizimu Afrika sinabaPhostoli J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu kanye noE.Mzamo. EMozambique AbaPhostoli Ntimbane, Mthise, Bazar kanye nabaPhostoli abangasekho emhlabeni.""";

const String _xitsongaHistory =
    """Matimu ya The Twelve Apostles Church In Christ

1832 - Muapostola wa ku sungula J.B. Cardale
1835 - Kereke ya Catholic Apostolic yi simekiwile
1852 - C.G. Klibbe u velekiwile hi N'wendzamhala
1889 - Muapostola H.F. Niemeyer u rhumele muevhangeri Carl George Klibbe eAfrika Dzonga
1892 - Muapostola C.G. Klibbe u vekiwile tanihi muapostola eKholijini ya Vaapostola le Yuropa
1893 - Vanhu va tsevu va ku sungula va vekiwile mfungho eAfrika Dzonga eKapa - Vito ra Kereke a ku ri
New Apostolic Church
1913 - Ku avana ku sungurile loko Muapostola Klibbe a hambeta ni dyondzo ya khale ya kereke
loko Muapostola Lonkulu Niehaus a herisile hofisi ya muprofeta
1926 - Khoto ya Afrika Dzonga yi vule leswaku Muapostola Klibbe u fanele ku teka vito lerintshwa ra ntlawa wa yena. Vito a ku ri The Old Apostolic Church of Africa hikuva Muapostola Klibbe a a lava ku landzela dyondzo ya khale.
1931 - Hi Mudyaxihi Muapostola Klibbe u lovile. A a vekile n'wingi wa yena H. Velde ehansi ka vutirheli byakwe kambe na yena u lovile hi 1956 eka nghozi ya movha eKimberly.
Vaapostola lava Muapostola Klibbe a va vekile a ku ri Muapostola E. Ninow, C. Ninow na W. Campbell.
Muapostola wo sungula wa ntima a ku ri Muapostola Hlatshwayo, loyi a landzeriweke hi Muapostola Ndlovu.
1972 - Muapostola S.D. Phakathi u vekiwile hi Muapostola Ndlovu.
Va sungula The Twelve Apostles Church of Africa.
1978 - Muapostola S.D. Phakathi u simeka The Twelve Apostles Church In Christ.
Kereke yi tsarisiwile ximfumo hi Ndzhati 1978.

NKOMISO WA MATIMU YA THE TWELVE APOSTLES CHURCH IN CHRIST
Tanihi Vakreste hinkwerhu ha swi tiva leswaku Yesu Kreste i Hosi, naswona u ni vulawuri bya vukwembu lebyi hlanganisaka hinkwato. Matewu u ri "matimba hinkwawo ndzi nyikiwile wona etilweni ni misaveni." [ Mat.28.18.] Tatana u veke hinkwaswo emavokweni yakwe.[Yoh.3.35. ] Vulawuri bya yena u nyikiwile byona hi Tatana etilweni. [ Luk. 10.22.]

A hi tsundzukeni leswaku Yesu a swi tiva leswaku a nge tshami emisaveni hilaha ku nga heriki. Hi dyondza eka tidyondzo ta yena ndlela leyi a a lava leswaku vutirheli bya yena byi hambeta ha yona emisaveni. U hlawule vavanuna va khume na mbirhi a va vula Vaapostola va yena. Leswaku va rhangela kereke hi matimba ni vulawuri, Yesu u va nyike xiphemu eka matimba ya yena ya vukwembu.
Yesu u ri Vaapostola va rhumiwile tanihi leswi Tatana a n'wi rhumeke ha swona. [ Yoh. 20.21 ]. Va fanele ku vula ntiyiso hi muxaka lowu fanaka wa matimba lawa Yesu a a ri na wona, hikuva Yesu u ri un'wana ni un'wana loyi a va yingisaka u yingisa Yena. [ Luk.10.16. ]
Eka Yoh.20.23. u va nyika hi ku kongoma matimba ya yena ku rivalela swidyoho. Yesu u fanele a ri ni xikongomelo xa leswaku vutirheli bya yena byi hambeta hikuva eka Matewu 28.20 u tshembisa ku va swin'we ni Vaapostola ku ya fika emakumu ka nkarhi. Endzhaku ka sweswo eka evhangeli ya Yohane u tshembisa Moya lowo Kwetsima leswaku wu ta pfuna hi ntirho wo twisisa Ntiyiso, [ Yoh 16.13. ] naswona u ri Moya lowo Kwetsima wu ta tshama ni Vaapostola hilaha ku nga heriki. [Yoh 14.16. ]
Vutirheli lebyi byi tisiwile eka hina eAfrika Dzonga hi Muevhangeri Carl Geog Klibbe hi 1889. U rhumiwile hi Muapostola H.F.Niemeyer wa le Queensland eAustralia. Tanihi leswi Muevhangeri Klibbe a a titshege hi vurimi leswaku a tiphilisa, loko a fika eKapa hi 1889 u xave purasi leritsongo eBellvile, kambe endzhaku a rhurhela eWorcester hikuva a a kota ku vulavula Xijarimani ntsena. U sungule vutirheli byakwe hi ku dzikisa mianakanyo swinene eka vaaki lava vulavulaka Xijarimani.
Vumbhoni byakwe byi sungule ku tswala mihandzu hi 1892 loko nhlengeletano yitsongo yi humelela eAfrika Dzonga ra ku sungula. Hi 1901 muendli wa tintanghu loyi vito rakwe a ku ri George Heinrich Schlaphoff swin'we ni ndyangu wakwe, lava vona a va ri vahlapfa lava humaka eJarimani va endzerile nhlengeletano. Schlaphoff u kokiwe rinoko swinene hi vumbhoni lebyi naswona ku nga ri khale yena ni ndyangu wakwe va amukeriwile. Va vekiwe mfungho hi Muapostola Carl Klibbe hi Pentekosta ra 1902. Makwerhu Schlaphoff u vile ni nkucetelo lowukulu naswona a a tinyiketele swinene entirhweni wa Hosi. Endzhaku u rhurhele eKapa ku ya hangalasa Rito kwalaho.
Tinkonzo ta vuXikwembu leti a ti khomeriwa endlwini ya Muevhangeri Schlaphoff a ti tshama ti tele hi ku hatlisa. Kwalaho kereke yo sungula yi akiwile naswona yi nyikeriwile hi Muapostola Klibbe hi Pentekosta, 4 Khotavuxika 1906.
Ku avana ko vava exikarhi ka Muapostola Klibbe na Muevhangeri Schlaphoff ku sungule eKapa hi 1910. Xivangelo xa xiviri xa sweswo xa ha kanetiwa. Leswi swi hambetile ku fikela loko ku va ni ku avana exikarhi ka swirho swa kereke. Xiyimo xi nyanyile endzhaku ka loko Schlaphoff a vekiwile ku va Muapostola eJarimani, naswona a ku ri ni mintlawa yimbirhi ekerekeni. Ku pfilunganyeka loku ni madzolonga yo vava swi lulamisiwile ehubyeni ya milandu hi 26 N'wendzamhala 1926. Xiboho xa khoto a ku ri xa leswaku Muapostola Klibbe a a fanele ku hambeta ni mintirho yakwe tanihi "The Old Apostolic Church" naswona Muapostola Schlaphoff a hlayisa vito ra "The New Apostolic Church".
Muapostola Klibbe u hambetile ni vutirheli byakwe tanihi "The Old Apostolic Church" naswona kereke yi ponisile mimoya yo tala. Leswi swi endle leswaku swi va swa nkoka leswaku Hosi yi n'wi katekisa hi Vaapostola vo tala ku fika emasikwini ya Muapostola F.W.Nino. Muapostola Nino u tlhele a hoxa xandla eku kuriseni ka kereke ku fikela loko yi va na nhlayo yikulu ya valandzeri va vantima. Muapostola Nino u vekile Muapostola wa Ntima wo sungula hi 1953 loyi vito rakwe a ku ri Samuel Hlatshwayo. Muapostola Hlatshwayo u lovile hi 1961 ivi Muapostola Nino a veka Muapostola J.S.Ndlovu.
Endzhaku ka rifu ra Muapostola Nino vuxaka exikarhi ka Muapostola J.S.Ndlovu ni vatirhi-kulobye va valungu byi onhakile. Xivangelo xikulu xa sweswo a ku ri xiyimo xa tipolitiki ta le Afrika Dzonga hi nkarhi wolowo wa "Xihlawuhlawu", lexi xi vangeleke ku avana ekerekeni hi 1968. Muapostola J.S.Ndlovu u tshamile ekhaya hi ku miyela nkarhinyana. Nseketelo lowu a a ri na wona a wu hlamarisa. Vaseketeli va yena va yile ekaya rakwe hi vunyingi ku n'wi khutaza leswaku a hambeta ni ntirho wakwe lowunene. U hambetile ehansi ka vito lerintshwa ra 'The Twelve Apostles Church in Africa'. Tanihi leswi a a swi tiva kahle leswaku a a nge koti ku lwisana na vakaneti va yena va valungu, Muapostola Ndlovu u endle xiboho xa leswaku mhaka leyi yi nga ka yi nga lulamisiwi ekhoto, a nga lavanga hambi ku ri ku voniwa hi vanhu kumbe hi valawuri. A nga pfumelelanga leswaku thelevhixini kumbe swifaniso swa tinhlengeletano ta yena ta kereke swi tekiwa. Mikarhi hinkwayo a a dyondzisa valandzeri va yena leswaku va nga vuli mavito ya vanhu van'wana ngopfu ngopfu kereke ya Old Apostolic Church. U khutaze ntsena swirho swa yena ku chumayela evhangeli ntsena, ku nga ri swin'wana. U kombele valandzeri va yena ku huma hi ku rhula eka tiholo ta kereke ta Old Apostolic Church ivi a va nyika mapapila ya xikombelo xo tirhisa makamara ya swikolo ku fambisa tinkonzo ta vona. Leswi u swi endlile ehansi ka milawu yo tika ya valawuri. A a endzela swikolo sweswo exihundleni hi nkarhi wa tinkonzo ku tiyisisa leswaku va yingisa milawu ya valawuri. A a fanele a kombela mpfumelelo wo fambisa tinhlengeletano ta le handle ta vanhu vo tala. Tinkonzo takwe ta moya ti koke rinoko ra swirho swo tala, ngopfu ngopfu emadorobeni ni le matikweni yo tanihi Botswana, Swaziland ni Mozambique. Swilo a swi nga olovi eMozambique lerova eka nkarhi wun'wana u boheke ku fambisa inkonzo emahlweni ka vatirhela-mfumo lava va teke ku ta vona leswi a swi endlaka. U tile eAfrika Dzonga a tsakile swinene hikuva vatirhela-mfumo va Mozambique va kumbiwe hi Moya lowo Kwetsima ivi va n'wi nyika mpfumelelo wo hangalasa evhangeli eMozambique. Endzhaku ka inkonzo yoleyo mimoya yo tala yi ponisiwile naswona yi vekiwe mfungho eswiphen'wini swo tala swa Mozambique. Hi Ndzhati 1972 u vekile Muapostola S.D.Phakathi eDurban. Muapostola Ndlovu u tinyiketelele holo yakwe yo sungula ya kereke eMeadowlands Soweto hi 1977.
Hi 1978 Muapostola Ndlovu u yile ni vuyimeri byakwe eMozambique ku ya fambisa inkonzo ya kereke. A swi tiva leswaku leri a ku nge vi riendzo ro hlayiseka hikuva Xikwembu a xi vulavurile. Leswi swi ve erivaleni eka hinkwavo hi nkarhi wa inkonzo yo hetelela yo tivonana leyi a yi fambisele eka holo ya yena yintshwa ya kereke eMeadowlands. Eka inkonzo yoleyo u vulavurile hi swilo leswi n'wi humeleleke enkarhini lowu hundzeke na leswi swi nga ha n'wi humelelaka enkarhini lowu taka. Inkonzo yoleyo a yi fana swinene na xirilo xa yena ku tlula inkonzo yo tivonana. A swi fana ni le masikwini yo hetelela ya Yesu Kreste loko a byela Vaapostola va yena hi riendzo ra yena ro ya eka Tatana wa yena etilweni. [ Yohane 14. ] Vo tala lava a va ri kona naswona va twisisaka leswi Xikwembu xi swi vuleke, a va nge n'wi pfumeleli leswaku a teka riendzo rolero loko a va ri na ku hlawula. Hi ntshembo wa yena eka Hosi, tanihi Hosi Yesu Kreste Muapostola Ndlovu a a ri ni vurhena naswona u yile eMozambique.
Loko Muapostola Ndlovu a teka nkarhi lowo leha ku tlula lowu a wu languteriwile ku vuya eMozambique, swirho swa kereke swi sungule ku vilela hikuva a swi vikiwile eka phepha-hungu rin'wana ra kwalaho leswaku u le xiphiqweni na valawuri eMozambique.
Loko vuyimeri byakwe byi vuya eMozambique, Muapostola Ndlovu na nsati wakwe va sale endzhaku. Vuyimeri a byi ri na swiviko swimbirhi leswi hambaneke mayelana ni leswi endlekeke eMozambique. Ntlawa wun'wana wu tiyisise xiviko xa phepha-hungu xa leswaku Muapostola Ndlovu u le xiphiqweni eMozambique. Ntlawa lowun'wana wu vule leswaku sweswo a hi ntiyiso Muapostola Ndlovu a a fambisa tinkonzo to veka mfungho eSwaziland naswona u ta vuya ku nga ri khale.
Ntlawa wa valanguteri lava va tiyisiseke xiviko xa phepha-hungu, lowu a wu rhangeleriwa hi mulanguteri N.V.Mlangeni, loyi a peleketile Muapostola Ndlovu eMozambique wu yile eka Muapostola S.D.Phakathi eDurban ku ya vika leswi humeleleke eMozambique. Loko va vuyela eJoni ntlawa lowu lwisanaka na vona wu vule leswaku va yile va ya hleva eDurban, hikokwalaho va hlongoriwile ekerekeni swin'we ni Muapostola S.D.Phakathi. Leswi swi vange pfilunganyeko lowukulu exikarhi ka swirho swa kereke naswona va avanisiwa hi mintlawa yimbirhi. Muapostola S.D.Phakathi a a nga ri na ntshembo wun'wana ehandle ko tirhela Hosi ehansi ka vito rir'wana ku fikela loko Muapostola Ndlovu a vuya. Valandzeri va yena a va tiviwa tanihi "United Twelve Apostles". Tin'hweti ti hundzile ku ri hava nfungho wa Muapostola Ndlovu naswona Muapostola Phakathi u tsarise kereke tanihi "The Twelve Apostles Church In Christ". Hi nkarhi lowu Muapostola Ndlovu a vuyeke ha wona eAfrika Dzonga a swi tika swinene ku hlanganisa tikereke leti timbirhi hikuva vuxaka exikarhi ka swirho a bya ha onhakile swinene.
Muapostola Phakathi u hambetile ni kereke ya yena, kambe a ha tixixima ngopfu Muapostola Ndlovu, a a tala ku n'wi vula Tatana wa yena. TACC yi kurile hi xihatla lexikulu swinene ehansi ka S.D.Phakathi hikuva u nghenise migingiriko yo tala ekerekeni naswona a a dzikise mianakanyo ngopfu eka vantshwa ni vakhalabye. U kokele vanhu va malembe hinkwawo ekerekeni. Ku tlula hinkwaswo a a ri munhu wa xinghana swinene naswona un'wana ni un'wana a a n'wi rhandza ngopfu ngopfu vantshwa, a a ri nhenha ya vona. Swirho swi andzile ni le matikweni man'wana yo tanihi Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi, Zambia ni le Botswana. Nkhuvo wo hetelela wo nkhensa lowu khomeriweke exitediyamini xa Absa eDurban hi Ndzhati 1991, wu kombise ndlela leyi Xikwembu xi n'wi katekisiseke ha yona. Xitediyamu xa Absa a xi tele ku fikela emakumu, naswona u veke Vaapostola va ntlhanu hi siku rolero. Muungameli wa sweswi wa TACC N.V.Mlangeni, Xandla xa Muungameli N.C. Khumalo, ni Muapostola W.Gelem va vekiwile hi siku rolero. Hikwalaho ka xirho lexi kulaka, Muapostola Phakathi u khutaze swirho swakwe ku xava purasi eUmkomaas eDurban hi mali ya vona vini naswona u sungule ntirho wo aka misava ya kereke wa timiliyoni ta tirhandu eUmgababa leyi nga yindlu-nkulu ya The Twelve Apostles Church in Christ namuntlha. Muapostola Phakathi a a ri na mianakanyo leyikulu ngopfu hi kereke. A a ri na makungu yo aka xitediyamu epurasini naswona u vule leswaku xivumbeko xa yona xi ta swi olovisa, hikuva yi se yi vumbiwe ku fana na yona. Purasi ri ya emahlweni ri tirhiseriwa swiendlakalo leswikulu swa kereke namuntlha. Ku lova ka Muapostola Phakathi hi ti 6 Ndzhati 1994 ku fikile tani hi xihlamariso eka swirho swa kereke naswona u ta tshama a tsundzukiwa. Inkonzo ya xirilo xakwe yi khomeriwe epurasini leri a ha ku ri xavaka. Swirho swo tlula 40 000 swi tile ku ta xixima nhenha ya vona ro hetelela.
Swi fane ni xibalo kambirhi eka swirho swa kereke leswi ana se a swi twile ku vava loko ku va ni ku avana exikarhi ka Vaapostola lava seleke, mayelana ni leswaku i mani loyi a nga ta va "NHLOKO" ya kereke. Vito "NHLOKO" ri dumile ngopfu naswona ri pfuxe swivilelo swo tala eka vanhu, ngopfu ngopfu lava a va tile ekerekeni ku ta gandzela. Kereke yi avane hi mintlawa yimbirhi. Muapostola N.V.Mlangeni u hlawuriwe tanihi muungameli lontshwa hi Muapostola N.C. Khumalo loyi a a ri muhlanganisi wa kereke hi nkarhi wolowo hi 1995, ivi Muapostola Khumalo a va phini. Hi 29 Hukuri 1995 mintlawa yimbirhi yi tlangere siku ra vona ro nkhensa epurasini kambe hi ku hambana. Vaapostola C.Nongqunga na W.Gelem exiphen'wini xin'wana xa purasi swin'we na valandzeri va vona ivi Vaapostola N.V.Mlangeni na N.C. Khumalo lebaleni lerikulu ra purasi swin'we na valandzeri va vona. Lexi a ku ri xiyimo xo vava swinene ku xi vona.
A ku ri na mihloti ya ntsako na kunyanyuka loko Muapostola W.Gelem na valandzeri va yena va vuyela ekerekeni hi 1997. U amukeriwile hi timbilu to kufumela hi Vaapostola N.V.Mlangeni na N.C.Khumalo ni swirho hinkwaswo swa kereke, handle ka swipimelo. Xiendlo lexi xi tikombe xi horisa timbanga ta nkarhi lowu hundzeke. Muapostola W.Gelem u katekise vana va Xikwembu hakunene hi tidyondzo takwe ta matimba, a a nga ri na nchumu kambe a a ri ndzilo ntsena. U hoxe xandla swinene eku hlanganiseni ka mintlawa leyi yimbirhi ku va kereke yin'we leyi hlanganeke hi tinkonzo ta yena ta matimba na ta Moya etikweni hinkwaro na le matikweni man'wana. Rungula ra yena ro hetelela eka swirho swa kereke hinkwako laha a yeke kona emasikwini ya yena yo hetelela a ku ri Matewu [5.8] ku katekile lava tengeke mbilu, hikuva va ta vona Xikwembu. Muapostola W. Gelem a a nga ha ri munhu loyi a hanyeke kahle hi nkarhi wolowo naswona u lovile hi 1998. Tidyondzo ta yena ta ha hanya na namuntlha. "Ku katekile lava tengeke timbilu hikuva va ta vona Xikwembu".

U lahliwile emutini wa kwavo eTsolo eVuxeni bya Kapa.
Muapostola Mlangeni ni Muapostola Khumalo va ye emahlweni ni vumbhoni naswona vuxirho bya kereke namuntlha byi kurile hi 300% loko ku pimanisiwa ni vuxirho emikarhini ya Muapostola S.D.Phakathi hi 1994.

Kwazulu Natal yi yimela phesente yikulu ya vuxirho. Mozambique na yona yi na nhlayo yikulu ya swirho. Inkonzo yo sungula yo veka mfungho yi khomeriwe eAngola hi 2006. Mulanguteri John Mthembu u endla ntirho wo hlamarisa swinene ematikweni yo tanihi Malawi, D.R.Congo, na Angola. Kereke yi kula ematikweni wolawo. Muapostola Miangeni u veke Vaapostola va khume ku ta fika namuntlha. EAfrika Dzonga hi na Vaapostola J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu na E.Mzamo. EMozambique Vaapostola Ntimbane, Mthise, Bazar na vaapostola lava lovileke.""";
