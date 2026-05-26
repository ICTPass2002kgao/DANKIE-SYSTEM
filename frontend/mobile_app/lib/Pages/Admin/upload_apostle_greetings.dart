// ignore_for_file: prefer_const_constructors, use_build_context_synchronously, avoid_print

import 'dart:convert';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ttact/Components/API.dart';
import 'package:ttact/Components/NeuDesign.dart';

class AdminGreetingsManager extends StatefulWidget {
  final String? uid;
  final String? fullName;
  final String? portfolio;
  final String? province;

  const AdminGreetingsManager({
    super.key,
    this.uid,
    this.fullName,
    this.portfolio,
    this.province,
  });

  @override
  State<AdminGreetingsManager> createState() => _AdminGreetingsManagerState();
}

class _AdminGreetingsManagerState extends State<AdminGreetingsManager> {
  bool _isUploading = false;
  List<dynamic> _dbGreetings = [];
  bool _isLoadingDB = true;
  int _selectedTabIndex = 0; // 0 = Bulk Upload, 1 = Manage Database

  // MASSIVE DATABASE OF ALL GREETINGS (Full History Preserved)
  final List<Map<String, dynamic>> _staticGreetingsData = [
    {
      'id': '2015_16',
      'year': '2015/16',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'President',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'en': {
          'title': 'Greetings for the Year 2015/16',
          'message':
              '''Beloved in the Lord,\n\nI write to you this letter which is the greetings of 2015/2016 being filled with amazing joy and love about you my father's children.\n\nFirstly let me thank you all for your commitment in the church, and the love that I see within you. That alone means a lot to me; like I normally say to you that "love others as you love yourself" by so doing you will be loving the one who created you, because to look down upon your brother or sister and considering yourself to be better than they are, means that you still do not know even the one who created you.\n\nRemember the words that were spoken by our Lord when He rose from the dead; He says "beloved". We got a new name at that moment when the Lord resurrected from the grave. We should not forget that our creator said your body is the temple of God, he wrote his church in your body. The limbs in your body are twelve, they are six on one side and six on the other side, and they are twelve in total. They all work in harmony.\n\nThen He gave you the head and put brain inside it, which is your mind to think. He says you must think and do not be lazy to think, you must ask from God in whatever you do. When you ask for something that is good God will give you that which is good.\n\nDo not be like the king's daughter who could dance, when the king said to her; "my child you have danced very well, better than the other girls, therefore ask for anything you like and I will give it to you" Then she said, 'father I am asking for the head of John the Baptist" It was difficult for her father but because he had promised her anything, because he loved her, John had to be killed and his head was brought in a platter, and the king's daughter was happy and danced even more.\n\nHere then is a question that says: Was that a good request? It means if you ask for something good you will benefit that which is good and if you ask for something evil you shall be rewarded with that which is evil. Therefore learn to ask for something good to be rewarded with that which is good. You must learn to forgive so that you also can be forgiven.\n\nGod bless you with good health with your families.\n\nYours in Christ,\nN.V. Mlangeni''',
        },
        'nso': {
          'title': 'Ditumedišo tša Ngwaga wa 2015/16',
          'message':
              '''Baratiwa Moreneng,\n\nKe le ngwalela lengwalo le e lego ditumedišo tša 2015/2016 le tletše lethabo le lerato le legolo ka lena bana ba tate.\n\nSa mathomo e re ke le leboge ka moka ga lena bakeng sa boikgafo bja lena kerekeng, le lerato leo ke le bonago go lena. Seo se nnoši se ra go gontši go nna; bjalo ka ge ke fela ke le botša gore "rata ba bangwe bjalo ka ge o ithata" ka go dira bjalo o tla be o rata yo a go hlotšego, gobane go nyatša ngwaneno goba kgaetšedi ya gago le go ipona o le kaone go ba phala, go ra gore ga o ešo wa tseba le yo a go hlotšego.\n\nGopola mantšu ao a boletšwego ke Morena wa rena ge a tsoga bahung; a re "baratiwa". Re hweditše leina le lefsa ka nako yeo ge Morena a tsoga lebitleng. Re se ke ra lebala gore mmopi wa rena o itše mmele wa gago ke tempele ya Modimo, o ngwadile kereke ya gagwe mmeleng wa gago. Ditho tša mmele wa gago di lesomepedi, di tshela ka lehlakoreng le lengwe gomme di tshela ka go le lengwe, di lesomepedi ka moka. Di šoma mmogo ka kwano.\n\nKe moka a go fa hlogo a tsenya bjoko ka gare ga yona, e lego monagano wa gago wa go nagana. O re o swanetše go nagana o se ke wa tšwafa go nagana, o kgopele go Modimo go se sengwe le se sengwe se o se dirago. Ge o kgopela se sebotse Modimo o tla go fa se sebotse.\n\nLe se ke la swana le morwedi wa kgoši yo a bego a kgona go bina, ge kgoši e re go yena; "ngwanaka o binne gabotse kudu, go phala basetsana ba bangwe, ka gona kgopela se sengwe le se sengwe se o se ratago gomme ke tla go fa sona" Ke moka a re, 'tate ke kgopela hlogo ya Johane Mokolobetši" Go be go le thata go tatagwe eupša ka gobane o be a mo tshepišitše se sengwe le se sengwe, ka gobane o be a mo rata, Johane o be a swanetše go bolawa gomme hlogo ya gagwe ya tlišwa ka sebjana, gomme morwedi wa kgoši o be a thabile gomme a bina le go feta.\n\nFa go na le potšišo yeo e rego: Na eo e be e le kgopelo e botse? Se se ra gore ge o kgopela se sebotse o tla holega ka se sebotse gomme ge o kgopela se sebe o tla putswa ka se sebe. Ka gona ithute go kgopela se sebotse gore o putswe ka se sebotse. O swanetše go ithuta go lebalela gore le wena o lebalelwe.\n\nModimo a le šegofatše ka maphelo a mabotse le malapa a lena.\n\nWa lena go Kriste,\nN.V. Mlangeni''',
        },
        'zu': {
          'title': 'Umbuliso wonyaka ka-2015/16',
          'message':
              '''Bathandekayo eNkosini,\n\nNginilobela lencwadi engumbuliso ka-2015/16 ngigcwele ukujabula okuyisimangaliso nothando oluyisimangaliso ngani bantwana bakababa.\n\nOkokuqala mangibonge kini nonke ukuzimisela kwenu enkonzweni, nothando engilubona phakathi kwenu. Lokho-nje kukodwa kimina kusho okukhulu; njengoba ngike ngisho kini ukuthi "thanda omunye njengoba uzithanda wena uqobo lwakho" ngalokho uyobe uthanda lowo owakudalayo. Ngoba ukubukela phansi umfowenu noma udadewenu, uzibone wena ukuthi ungcono kunabo, kusho ukuthi nokudalileyo awukamazi.\n\nKhumbula mazwi akhulunywa iNkosi yethu uma ivuka kwabafileyo; ithi: "bathandwa". Sathola igama elisha ngaleso sikhathi uma iNkosi ivuka ethuneni. Singakhohlwa ukuthi owasidalayo wathi umzimba wakho uyithempeli lika-Nkulunkulu, wayibhala inkonzo yakhe emzimbeni wakho. Amalungu emzimbeni wakho ayishumi nambili, ngasohlangothini lwakho ayisithupha, nakolunye uhlangothi ayisithupha, bese ehlangana abe yishumi nambili. Asebenza wonke ngokuzwana.\n\nWabe esekupha ikhanda wafaka ubuchopho phakathi kwalo, okuyingqondo yokucabanga. Uthi cabanga ungavilaphi ukucabanga, ucele ku-Nkulunkulu noma ngabe wenzani. Uma ucela okulungile uNkulunkulu uyokupha okulungile.\n\nUngalingisi intombi yenkosi eyayikwazi ukusina, lapho inkosi yathi kuyo mntanami usine kahle ukwedlula ezinye izintombi, ngakho-ke cela noma yini oyithandayo ngizokunika kona, yayisithi baba ngicela ikhanda lika Johane umbhabhadisi. Kwaba lukhuni kuyise wayo kodwa ngoba wayeyithembisile ukuthi noma yini ngoba eyithanda, kwafanela ukuthi abulawe uJohane lalethwa-ke ikhanda lakhe libekwe oqwembeni, yajabula-ke intombi yenkosi yasina kakhulu.\n\nNawuke umbuzo uthi: kwakuyisicelo esihle leso na? Kusho ukuthi uma ucela okulhle uyozuza okuhle kodwa uma ucela okubi uyozuza okubi. Ngakho-ke fundani ukucela okuhle ukuze namukeliswe okuhle. Fundani ukuxolela ukuze nani nixolelwe.\n\nUNkulunkulu anibusise nibe nokuphila okuhle nemindeni yenu.\n\nYimi owenu kuKristo.\nN. V. Mlangeni''',
        },
      },
    },
    {
      'id': '2014',
      'year': '2014',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'President',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'en': {
          'title': 'Year closing message',
          'message':
              '''I greet you all in the good name of our Lord Jesus Christ.\n\nFirstly I wish to thank the good works that you have done in the church of Christ, by preaching the gospel for the congregation to be eager to work in unity in doing the duties given to it, and also for the evangelical brothers to take interest in wearing their evangelical uniform. Not forgetting to thank our mother apostles, and sister overseers, district elders, community elders, priests and deacons, for teaching our sisters to also do what they have been sent to do.\n\nAll this would not have happened if there was still disrespecting of one another. This happens because they still have conscience within themselves. What is most important is respect among ourselves. All godly things will happen only if we respect one another, when the young respect the old and the old respect the young, loving one another with godly love not pretending. God does not want someone who pretends.\n\nYou may find in some places officers feeding each other with evil spirit of rebelling against their leaders by not accepting to be led by them, and seeking to be led by officers of their choice. There is nothing better than when each one remains where the apostle has put them. When there is a misunderstanding or difference of opinion, sit down and each one present their case and sort out what has gone wrong with respect to each other. By so doing we would be respecting the apostle.\n\nGod will bless us and let us all live with our families\n\nI wish you wonderful holidays, may you all begin the New Year in good health. You must also wish each other a Merry Christmas and move into the New Year with blessings. We also thank that this year 2014 God has blessed us with a star-an apostle. We thank that because this would not have happened if the God of this church was not alive.\n\nI thank you all and I love you all!\n\nYours in the Lord\nN. V. Mlangeni.\nPresident.''',
        },
        'zu': {
          'title': 'Umlayezo wokuvala unyaka',
          'message':
              '''Ngiyanibingelela egameni elihle lenkosi yethu uJesu Kretu.\n\nOkokuqala mangibonge imisebenzi emihle eniyenzile enkonzweni ka-Krestu, yokushaya ivangeli, ukuze ibandla likhuthalele ukuhlanganyela imisebenzi elinikezwa yona, nokuthi abavangeli bakhuthalele ukwembatha isambatho somvangeli. Ngingakhohlwa ukubonga oma-mpostoli nabo bonke oma-mvelelil, oma-district, oma-ouster, oma-priest Kanye noma-mshumayeli ngokufundisa odade ukuthi nabo benze abakuthunywayo.\n\nKonke lokhu bekungeke kwenzeke uma bekusekhona ukwedelelana. Lokhu kwenzeka ngoba unembeza esekhona phakathi kwabo. Okubaluleke kakhulu yinhlonipho phakathi kwethu. Zonke izinto zobu Nkulunkulu ziyokwenzeka kuphela-nje uma sihloniphana, omncane ahloniphe omdala, nomdala ahloniphe omncane, sithandane sonke ngothando luka-Nkulunkulu, hayi elokuzenzisa. Unkulunkulu akamfuni umuntu ozenzisayo.\n\nUngathola kwezinye izindawo izinceku zifakana umoya omubi wokuvukela izinceku ezingenhla ngokungavumi ukukhokhelwa yizo, zifune ukukhokhelwa yizinceku ezithandwa yizona. Akukho okwedlula ukuthi omunye nomunye ahlale lapho umpostoli embeke khona. Uma kukhona ukungezwani noma ukungaboni ngaso linye, kuhlalwe phansi, omunye nomunye abeke isikhalo sakhe, kulungiswe lokho okungalungile ngokuhloniphana. Ngokwenza lokho siyobe sihlonipha umpostoli.\n\nU-Nkulunkulu uyosibusisa siphile sonke nemíndeni yethu.\n\nNginifisela amaholidi armahle, ningene onyakeni omusha niphilile nonke. Nani nifiselane ukhisimusi omuhle ningene onyakeni omusha nezibusiso. Sibonge futhi ukuthi kulonyaka-ka 2014 lapho uNkulunkulu esibusise khona ngenkanyezi-umpostoli. Siyakubonga lokho ngoba bekungeke kwenzeke uma uNkulunkulu walenkonzo engaphili.\n\nNgiyanibonga nonke, futhi nginithanda nonke!\n\nYimina owenu eNkosini\nN. V. Mlangeni.\nUmongameli''',
        },
      },
    },
    {
      'id': '2013_14',
      'year': '2013/14',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umpostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'en': {
          'title': "Apostle's Greeting for 2013/2014",
          'message':
              '''Beloved in the Lord, I greet you in the good name of our Lord Jesus Christ.\nLet me begin by greeting the Apostle Board, the Central Council, and the Lower House. I greet the Central Youth Committee, I greet all officers from the community elder, priest, evangelist, and brothers and sisters. Not forgetting mother apostles and mother overseers, and all female officers.\n\nI want to thank you all for the huge role you played in the church, nation of our father. Even when strong winds shook you, you said "we are not moving here, even if our hands break off, we will hold on."\n\nYou, children of God, sweated and worked hard making ends meet, selling tomatoes on the streets, burned by the sun and rained on, your children sleeping hungry because you were trying to get money to build houses of worship. And when you finished building those houses, even if some were not fully complete but you were worshipping in them, along came a dragon, a big snake, and pushed you out of your houses that you built with difficulty.\n\nThe word of the apostle said come out, children of the father, and leave the empty shells that cannot do anything for themselves. Indeed you came out - not because you are cowards but you respected the word of the apostle and did as he said, I thank you very much.\n\nIf you remember I said to you tricks and cleverness come to an end, but foolishness does not. The clever do not enter the kingdom of heaven, and God does not go with the clever. God gave you strength, and you will build other houses. Stay in one hope.\n\nHave a wonderful and comfortable day here in Pretoria. May God bless you on your journeys, go with you, and may you always live by breaking bread. Diseases will decrease and there will be health all the time, and respect and love one another.\n\nPeace be among you.\n\nYours,\nN.V. Mlangeni.\nApostle.''',
        },
        'zu': {
          'title': 'Umbuliso wolMpostoli wonyaka ka-2013/2014',
          'message':
              '''Bathandekayo eNkosini, ngiyanibingelela egameni elihle leNkosi yethu Jesu Kristu.\nAngiqale ngibingelele indlu yabapostoli (Apostle Board), ngibingelele nendlu engenhla (Central Council), nendlu engenzansi (Lower House). Ngibingelele i-Central Youth Committee, ngibingelele zonke izirceku kusukela kumdala webandla, umprisita, unshumayeli kanye nomzalwane nodade. 'gingakhohlwa o-mampostoli no-mamveleli, no-manyanga no-manesi benkonzo, oma-mprisita, oma-mshumayeli kanye nodade balenkonzo.\n\nNgithi mangibonge kini nonke ngeqhaza elikhulu enalibamba enkonzweni sizwe sikababa. Kwala umoya omkhulu unixakazisa kepha nathi "asisuki la, kungamane kungamuke izandla sibambelele."\n\nIgundwane lizimbela umgodi lapho lizohlala khona, bese kuthi uma seliqedile, selihlezi kamnandi nosapho Iwalo, afike ufeleba, inyoka phela, engakwazi ukuzenzela lutho yona, ifike ixoshe amagundwane emzini wawo ihlale khona inethezeke emzini engawakhanga ngamandla ayo, ngoba yona iyisiqhwaga.\n\nNani bantwana baka-Nkulunkulu najuluka nasebenza kanzima nipatanisa, nithengisa otamatisi.ezindlelani, nishiswa yilanga ninethwa nayizimvula, izingane zenu zilale zingadlile ngoba nizama ukthi nithole imali yokwakha izindlu zokukhonzela. Kwathi lapho niqeda khona ukwakha lezo zindlu, noma ezinye zingakapheli kahle, kodwa senikhonzela kuzona, wafika u-dragoni inyoka enkulu wanidudula ezindlini zenu enazakha kanzima.\n\nLathi izwi lompostoli phumani bantwa baka-baba nidedele izihonga, ezingakwazi ukuzenzela lutho zona. Ngempela naphuma- hayi ngoba-ningamagwala kepha nahlonipha izwi lompostoli nenza njengoba eshilo, ngiyanibonga kakhulu. Isambane siyawumba umgodi singahlali kuwo, ngokuxakaziswa yizinja sibaleke siyokwemba omunye phambili. Kungakho kuthiwa amandla esambane awapheli.\n\nUma ningakhumbula ngathi kini amaqhinga nokuhlakanipha kuyaphela, kodwa ubulima abupheli. Izihlakaniphi azingeni embusweni wezulu, futhi noNkulunkulu akahambisani nezihlakaniphi. U-Nkulunkulu wonipha amandla, nozakha ezinye izindlu. Hlalani ethembeni....... elilodwa, ningabi namathemba kodwa nibe nethemba elilodwa.\n\nNibe nosuku olumnandi ninethezeke lapha e-Pitoli. U-Nkulunkulu anibusise nasezindleleni, ahambe nani, nihlale ngokuhlephula isinkwa njalo. Ziyoncipha nezifo kube yimpilo sonke isikhathi, futhi nihloniphane nithandane.\n\nNibe nokuthula phakathi kwenu.\n\nOwenu\nN.V.Mlarigeni.\nUmpostoli.''',
        },
      },
    },
    {
      'id': '2012_13',
      'year': '2012/13',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso wonyaka-ka 2012-2013',
          'message':
              '''Ngiyanibingelela egameni elihle leNkosi yethu nomsindisi uJesu Krestu.\n\nAngithathe lelithuba ngibonge umzalwane nodade, ngemisebenzi emihle abayenzile ukusindisa abantu baka-Nkulunkulu kumakhamandelo ekade beboshwe kuwona. Yebo, bengebodwa kepha bekanye nomshumayeli wevangeli.\n\nNgibonge futhi no-mprisita, nenesi yezulu, kanjalo nenyanga yezulu. Ngibonge futhi kanye nengelozi yasezulwini ngokwembathisa lesisizwe ingubo emhlophe qwa, egenachaphaza. Ngalokha sakhuseleka isizwe sikababa kwaze kwabo lapha esikhona namhlanje.\n\nNgakho-ke ngithi: Phambili bantwana bendlu ka Israeli! Asiyidumise njalo iNkosi enesihawu nomusa uJesu Krestu. Uma-nje singavuma ukulahla imisebenzi ka-Adamu omdala angeke uNkulunkulu angasiphi esikucelayo ngegama lakhe. Kuphela-je uma simcela ngendlela ayifunayo, sizithobe, sizehlise, sihloniphane, sibe ngabantwario, sibe nothando, singabukelani phansi, sihloniphe izinceku zoMpostoli. Sithande abapostoli uNkulunkulu asiphe bona, siyobe sithathanda izimpilo zethu. Ingoyama iyosithwala ngamahlombe ayo abanzi isise kuKrestu.\n\nAsidumise-ke sonke siyibonge iNkosi. Iziło zonke ziphele namhlanje, kanye nobubha buphele. Sihlaje ngokuhlephula isinkwa emakhaya ethu. uNkulunkulu uyosibusisa ngaso sonke isikhathi.\n\nOwenu eNkosini,\nN.V.Mlangeni\nUmongameli.''',
        },
      },
    },
    {
      'id': '2011_12',
      'year': '2011/12',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso woMpostoli wonyaka-ka 2011-2012',
          'message':
              '''Bathandekayo eNkisini,\nNgiyanibingelela egameni elihle leNkosi yethu uJesu Kristu.\n\nNjengoba sisuka kuzindawo ezahlukene kumagumbi omane omhlaba, sizodumisa uMdali ngeNdodana yakhe uJesu Krestu, ngithanda ukusho ukuthi nathi sinishumayeza lona ilizwi esalizwa lokuthi uNkulunkulu ungukukhanya, ubumyama abukho kuye nakanye. Uma sithi sinenhlangayelo naye kodwa sibe sisahamba ebumnyameni, sinamanga ngoba iginiso alikho kithi. Kepha uma sihamba ekukhanyeni njengalokhu yena uqobo esekukhanyeni, nathi asibe sekukhanyeni omunye nomunye. Ngegazi likaJesu iNdodana yakhe uyakusihlambulula ezonweni zethu zonke. Angikholwa ukuthi usekhona osayingabaza lenkonzo kaKristu, ngabe akuyena owalenkonzo.\n\nBobaba thandani omkenu, nani bomama thandani abayeni benu, ukuze nabantwana bafunde ukuthandana emakhaya ethu, bafunde ukuhlonipha abazali, nabo futhi bahloniphane bebodwa. Asiphathe kahle izihambi, sihloniphe omakhelwane bethu, sibathande njengoba sizithanda thina. Siyafunda ezincwadini ezingcwele ukuthi uNkulnkulu walithanda izwe kangaka, waze wathumela iNciodana yakhe ezelwe yodwa ukuthi izofela izwe.\n\nIzinto ezenzeka ezweni lonke zihlasimulisa umziba. Ngaphandle abantu bayabulalana bebodwa. Lesi yisikhathi sokuthi sihlangane sibe munye, sithandaze, singalilahli ithemba noma ngabe kunjani, sihlale kuyo ingoyama. Angeke mina nginilahle, ngiyokuwa ngivuka nani kuze kube sekugcineni. Ningabi namathemba kodwa nibe nethemba elilodwa. Ningamngabazi, akekho omunye nguye lo! Hlalani nonke ngamoya munye nithembane, omunye nomunye encekwini yakhe, ingonyama yona iyonithwala nonke emahlombe ayo abanzi inise ku-Kristu, uma nihlezi ngokuhlephula isinkwa sasezulwini, hhayi izindaba zabantu, namagama abantu.\n\nUNkulunkulu anibusise nonke! Akuthi ngokuhlangana kwethu kulendawo yaku-Tsolo, eMpumalanga Kapa izifo zonke ziphele namhlanje, enkonizwen ka-Krestu, abantwana bakababa baphile impilo enhle nemnandi nemindeni yabo, Amen!\n\nYimi owenu ku Krestu,\nN. V. MILANGENI.\nUMONGAMELI''',
        },
      },
    },
    {
      'id': '2010_11',
      'year': '2010/11',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso womPostoli wonyaka-ka2010-2011',
          'message':
              '''Bathandekayo e-Nkosini,\nNgiyanibingelela nonke egameni elihle leNkosi yothu uJesu Kristu, nginamukele futhi osukwini olukhulu kangaka esilwenzelwe yiyo iNkosi ngothando Iwayo nangomusa wayo.\n\nMangisho ukuthi njengoba ngasho ukuthi: uma ngabe sifuna ukubona uthando uNkulunkulu asisthanda ngalo, akuqale thina sithandane. Umama athande ubaba wakwakhe amhloniphe, nezingane zihloniphe abazali emakhaya.\n\nUmzalwane aziqhenye ngomshumayeli wakhe, nomshumayeli kanjalo ngoMprisita wakhe, noMprisita kanjalo ngoMdala wakhe, noMdala kanjalo ngo District wakhe, naye uDistrict kanjalo ngoMveleli wakhe, uMveleli naye aziqhenye ngoMpostoli wakhe, ingonyama iyonithwala nonke ngamahlombe ayo abanzi inise kukrestu.\n\nYasho kanjalo iNkosi yamakhosi yathi: hlalani ngokuthula eJerusalema, nihlephule isinkwa, nithandane, nibe munye njengami nobaba. Uma nenze kanjalo, mina nobaba sizohlala phakathi kwenu. Nibusisiswe uma benithuka, bekhuluma konke okubi ngani, beqamba amanga ngenxa yami. Jabulani nithokoze ngoba umvuzo wenu mukhulu ezulwini.\nNingaphindiseli ububi ngobubi, uJehova woninqobela.\n\nNibe nosuku oluhle nolumandi olnesibusiso.\nOwenu eNkosini,\nN.V.Mlangeni\nUmongameli.''',
        },
      },
    },
    {
      'id': '2009_10',
      'year': '2009/10',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso woMpostoli wonyaka-ka 2009/2010',
          'message':
              '''Bathandekayo eNkosini.\n\nNgiyanibingelela egameni lika Kristu oyinkosi nomsindisi wethu.\n\nAkengilethe ukubonga phakathi kwenu kulonyaka ka 2009/ 2010, sisagcinekile kuzilingo nokuhlupheka kwalomhlaba.\n\nMangisho lokhu ukuthi uNkulunkulu wethu uyaphila, uyasizwa uma simbiza sisebunzimeni bemisebenzi yesitha, njengokugula enyameni nasemoyeni. Kodwa-ke asingamkhumbuli kuphela uma sinobunzima esisuke sikubo, uma sekudlulile lokho bese siyakhohiwa uyena, bese sifana nomuntu ongakholwa, athi uma ehamba angabi nandaba noNkulunkulu uMdali wakhe akhulume nje umathanda, kodwa ake akhutshwe onyaweni lophe uzwane, ukhala kakhululu, ayibize inkosi akade enganandaba nayo athi; "awu nkosi yami, ngaze ngalimala." Kusho ukuthi ubuhlungu obunye nobunye buyamsondeza kuNkulunkulu, ayikhumbule inkosi yakhe ngaleso sikhathi, kuthi kungadlula akhohlwe abese ephindela futhi kuleziya zinto ekade ekhuzwa kuzo uNkulunkulu angazifuni.\n\nKonke lokho kudalwa yini? Ukungeneliseki, nobukhulu, nokuzibona ngingcono kunomunye umuntu. Ngiyaninxusa bathandekayo eNkosini ukuthi asizehlise sibe njengabantwana, sibe yize ukuze uNkulunkulu yena abe utho ngaphakathi kwethu. Sihloniphe umhlaba esiphila kuwo nababusi bawo.\n\nNgithanda ukusho ukuthi uma umuntu engahloniphi omunye umuntu usuke esephelelwe unembeza ngaphakathi kwakhe. Akufanele ukuthi sikhohlwe ukuthi uNkulunkulu wasipha inggondo yokucabanga, sazane ngimazi omunye umuntu ukuthi naye udalwe uNkulunkulu njengami, ubuhlungu abuzwayo nami ngiyabuzwa, futhi siyeke ukucabangelana izinto ezingenabu-Nkulunkulu, ezingekho, ngoba lokho ukudlinza, kanti siyafundiswa ukuthi ukudlinza kuyisono ngoba kungenzeka ukuthi udlinzela umfowenu noma udadewenu ngento engekho, ususesonweni ngoba usufana nomuntu obulele umphefumulo ongenacala.\n\nAsibe inkonzo, senze esakubizelwa kulenkonzo, sishumayele umbuso wezulu lapho ukrestu eyinkosi nomsindisi khona. Sibe noxolo nothando ngaphakathi kwethu. Kepha konke lokho kugale emakhaya. Ngiyazidla ngabavangeli, ugandaganda lo, Angisakhulumi ngenzalabantu, omama bomthandazo (blue train). Ingavinjwa ngubani? Ayimi eziteshini ezincane. Kuqhela yonke into esuke iphambi kwayo, kuphephuka konke okusemaceleni.\n\nAlishe Ivangeli bantwana baka-Baba. Izifo aziphele phakathi kwenu, namathuba emisebenzi awavuleke ezweni ububha buphele.\n\nOwenu ku-Krestu.\nN.V.Mlangeni\nUmongameli.''',
        },
      },
    },
    {
      'id': '2008_09',
      'year': '2008/09',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso Wompostoli wonyaka-ka 2008/2009.',
          'message':
              '''Bathandekayo elNkosini ngiyanibingelela. Ngithi ake nginikhumbuze ukuthi: ningakhohlwa eniylkho, nenakubizelwa kulenkonzo-ka "Christ". Nina niyi-thempell elingcwele lika-Nkulunkulu lapho u-Nkulunkulu ehlala khona, nanokuthi nabizeliwa ukuzosebenzela usindiso Iwemiphefumulo yenu kanye napakini abangasekhoyo. Siyokwenza lokho kuphela-nje uma sithandana, simunye.\n\nBathandekayo ningakholwa yibobonke omoya, kepha hlolani ukuthi bangabaka-Nkulunkułu yini ngokuba baningi abaprofethi bamanga abaphumele ezweni. Yazini umoya ka-Nikulunkulu ngatokhu; bonke omoya abavuma ukuthi u-Jesu Kristu ufikile enyameni bangabakhe, kukhona loyo moya ongavumi uJesu, akasiye oka-Nkulunkulu loyo. Loyo ungumphiki Kristu enizwe ngaye ukuthi uyeza, nokuthi usefikile ezweni. Nina ningabantwana baka Nkulunkulu, niwehlulite leyo moya ngoba okini mkhulu kunaloyo ośezweni. Borra bangabezwe ngalokho bakhuluma okwasezweni, nelizwe Hyabezwa. Thina singabaka-Nkulunkulu, omaziyo uNkulunkulu uyasizwa, ongasiye oka-Nkulunikulu akasizwa. Ngalokho masiwazi umoya ka-Nkulunkulu nomoya wokwedukisa.\n\nBathandėkayo masithandane ngoba uthando luvéla kuNkulunkulu, nabo bonke abathandanayo bazelwe uNkulunkulu. Ongathandiyo akamazi uŃkulunkulu. Omunye nomunye akathande umakhelwane wakhe njengoba ezithanda yena. Thandani izinceku nezincekukazi zenu, niyobe nithanda uNkulunkulu uqobo Iwakhe.\n\nNingene kahle onyakeni omusha ka-2009. Nituse okuhle enikubonlle, Mikhohlwe okubi enikubonile. Nizigubhe kahle izinsuku zika khisimusi.Unkulunkulu anibusise nonke onyakeni omusha nemindeni yenu yonke, nezifo zidambe niphile nonke.\n\nYimina owenu ku-Kristu,\nN.V.Mlangeni\nUmongameli.''',
        },
      },
    },
    {
      'id': '2007_08',
      'year': '2007/08',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'UMONGAMELI',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso woMpostoli wonyaka-ka-2007/2008',
          'message':
              '''Bathandekayo eNkosini.\n\nNgiyanibingelela nonke.\n\nNgithi akenginkhumbuze ukuthi uNkulunkulu wadala izulu nomhlaba, nolwandle. Eşekwenzile lokho wabe esehlukanisa amanzi nomhlaba njengalokhu kwakuhlangene. Wathi amanzi awabuyele nganxaye. Ngempela kwenzeka, yena uNkulunkulu wayesethi wulwlandle ke lolo.\n\nWayesethi-ke u"Nkulunkulu ulizwi" makubekhona okumilayo emhlabeni ukuze umhlaba ube muhle. Ngempela kwamila izihlahla, utshani, nezimbali, kwabakuhle. Wayesethi yena uNkulunkuklu kungakuhle uma kungabakhona izilwane ezihamba emhlabeni nezizondiza emkhathini zaba khona. Kwamjabulisa uNkulunkulu lokho ukubona izinyamazane zishona emigedeni yazo, nezinyoni zindizela ezihlahleni, zingena ezidlekekni zazo uma ilanga lishona.\n\nWazithola yena engenandawo, noma lapho engaqamelisa khona ikhanda lakhe. Wayesethi uNkulunkulu "nami ngizozakhela indawo lapho ngizohlala khona." Wayesebutha uthuli lomhlaba wenza ngalo umzimba womuntu wathi "leli yithempeli lami", walingcwelisa.\n\nKuba yinto ebuhlungu uma umuntu esephendula ithempeli likaNkulunkulu i-hotela, eseqashisa. E-hotela kungena zonke izinhlobo zabantu. Abathakathi, amakholwa, izigebengu, nababulali bayangena ehotela. Kukhuluma imali yalowo muntu. Kungakho-ke uMpostoli ebeka uphawu emabunzini abantwana bakhe. Eseqedile ukukwenaza lokho, uyabuya-ke manje unika omuye nomunye inkemba esandleni sakhe ukuba agence bonke abangenalo uphawu emabunzini abo.\n\nYibaphi abangenaphawu emabunzini abo na?\nInzondo, ukuzigabisa, ukubukela abanye phansi, ukugxeka, ukungahloniphani, nokunye. Uma uneso lokuhawukela, kungcono ulivale ukuze ukwazi ukuzigenca lezizinto, ngoba uNkulunkulu akazifuni ezulwini lakhe.\n\nUNkulunkulu anibusise nonke.\n\nOwenu ku-Kristu,\nN.V.Mlangeni.\nUMONGAMELI.''',
        },
      },
    },
    {
      'id': '2005_06',
      'year': '2005/06',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Umongameli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'UMBULISO WOMPOSTOLI KUZINCEKU ZONKE NAMABANDLA ONKE',
          'message':
              '''Bathandwa ku-Kristu\n\nNgiyanibingelela nonke egameni elihle lenkosi yethu nomfeli wethu uJesu Kristu. Mangisho ukuthi akesibonge ngazwi linye, uthando olungaka inkosi eyasithanda ngalo, yasifuna yasithola, yeza kithi, yahlala nathi. Akuthina esayifuna, iyona eyafuna thina ngoba ifuna ukutshengisa uthando Iwayo kithi ukuze sifunde ukuthi uthando luyinto enjani, sithandane, siyeke ukulwa ngoba inkosi ayibafuni abantu abaxabanayo. Ukuxabanana akuqhamuki ku-Thixo kepha kuqhamuka ezinkanukweni zenyama.\n\nOmunye nomunye akayithande inceku ebekwe phambi kwakhe ngoba yiwona umthombo wosindiso lowo, owavulwa ngenxa yakho. Uma uxabana nenceku yakho awehlukile kumuntu ogxuma ashaye ubonda ngekhanda lakhe, abesezikhohlisa athi "ngimlayile", kodwa uma ebheka lapho eshaye khona ngekhanda lakhe, afice ukuthi kunebala legazi, azikhohlise athi leligazi liphume obondeni, kanti liphume kuyena.\n\nSiyalwa bathandwa ukuthi sizithobe sibe njengabantwana, ofuna ukubamkhulu akaqale azithobe abemncane ukuze akhuliswe.\n\nNgathi kini ngomunye unyaka, umuntu noma engakholwa, ezibona eziphilela yena nje ngesingaye, akhohlwe ukuthi leyo mpilo ayiphilayo iveľa ku Nkulunkulu, uyena ophethe ukuphila kwethu. Ake akhutshwe loyo muntu ezwe ubuhlungu onyaweni lwakhe, uyomuzwa ethi "awu Thixo wami ngaze ngalimala". Okusho ukuthi kanti ubuhlungu buyamenza umuntu ukuthi akhumbule ukuthi akazidalanga, wadalwa ngu Thixo, abesesondela ku Thixo.\n\nNgabe sengithi kufanele ukuthi uma ungumuntu ocabangayo mfowethu nawe dadewethu ubohamba uhambe ubusuzincinza uzizwe ukuthi ingbe usayiphilela yini inkosi yakho noma cha, ngoba uyobulokhu uthi ayaphila kanti kudala wafa ebuthixweni, sekuyigobongo nje, noma usudikizelela ekufeni. Asiyiphilele inkosi ngokweqiniso, sibonakale siyibo abahambisi bezindaba ezilungileyo ngokushaya ivangeli loxolo nothando. Angibonge bavangeli ngokuphumelela kwenu ukuya eKapa ukuyodumisa inkosi, nani futhi nazizwa ukuthi niphila kangakanani, ngisho nanamhlanje kuseyindaba endabeni. Nawuqopha umlando bavangeli, usathane washutheka umsidlana wakhe phakathi kwemilenze yakhe. uThixo abe nani nemindeni yenu, nikhuseleke nonke ezinsukwini zika-khisimusi.\n\nNginifisela unyaka omusha omuhle, onezibusiso ku 2006.\n\nOwenu eNkosini\nN.V.MLÄNGENI\nUmongameli''',
        },
      },
    },
    {
      'id': '2004_05',
      'year': '2004/05',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Chief/President',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'UMBULISO KA 2004-2005',
          'message':
              '''Bathandekayo ku-Krestu,\n\nNgiyanibingelela egameni lenkosi yethu nomsindisi. Nginilobela lombuliso ngigcwele uthando olukhulu ngani bantwana baka baba.\n\nNgithanda ukusho ukuthi ngijabule kakhulu gokushaya kwenu ivangeli loxolo, nothando, neqiniso ezweni ukuze sisinde isizwe sika Nkulunkulu umdali wethu sonke. Yebo soguquka isizwe uma thina sihamba ngeqiniso, nangokwethembeka. Singatsheli abantu okuhle bathatheke, kodwa uma befika lapho esibabizela khona, bafice ukuthi akukho nokukodwa kwalokho, bafikelwe ukudumala nokushaqeka.\n\nUma kunjalo kuyobe asehlukile kubantu abaya ezweni bafice abantu begcwele udaka ezinyaweni bexakekile, bengazi ukuthi bangenza kanjani ukuthi loludaka olubasindayo ezinyaweni zabo lusuke (izinto zenyama). Bafike abazalwane nodade babashasyele ivangeli baguquke lababantu beze enkonzweni. Uma befika lapha enkonzweni, bathole isimanga, abantu lapha enkonzweni udaka seluze lwakhabathisa ezinyaweni zabo, akukho mehluko. Bese bethi kuyefana-nje, bese kugcwaliseka ukuthi: Uma kunje kwezimanzi, kuyobanjani kwezomileyo.\n\nNgiyaninxusa bafowethu nodadewethu, ake kubekhona umehluko kwabasenkonzweni yaba Postoli nabasezweni. Sibonakale ukuthi thina sathengwa ngenani elikhulu kakhulu - igazi lemvana u Jesu Krestu, owasifela esiphambanweni, saxolelwa ezonweni zethu, ngokuhlephuka kwenyama yakhe sasindiswa, ngokuchitheka kwegazi lakhe, saba nokuqonda nokwazi ngamanzi (imfundo), aphuma ohlangothini Iwakhe uma bemhlaba ngomkhonto.\n\nAkesiyeke ukukhalisana, kubekhona abanye abakhonza kamnandi enkonzweni, kubekhona abanye abakhonza ngezinyembezi. Abanye bakhonziswa abafowabo kabuhlungu enkonzweni, abanye bahlasliseke kabi emizini yabo ngenxa yabafowabo nodadewabo, noyise njengezinceku. Ngithanda ukunazisa zinceku ukuthi inceku eyotholakala ithinteka kuzigameko ezifana nalezi, iyoya emabhentshini igijima. Kufana nokuthathelana amabandla siyizinceku zomPostoli oyedwa. Umoya ongemuhle loyo.\n\nAsisebenze, omunye nomunye akazakhele umsebenzi umuhle. Musani ukuhawukela imisebenzi yabaye noma amagceke emizi yabanye, ngoba ehlanzekile emahle, nawe zenzele kube kuhle kwakho nomkakho umhlobise abemuhle nomyeni wakho abe muhle.\n\nKuzophela-ke ukuhawukela okwabanye abantu. Siyokubona ukubaluleka kwalemifula emithathu. Siyoba yiwo umfula wokuqala ukunguMvangeli, owesibili kube nguMelusi olungileyo, nowesithathu okungu Mprofethi. Akekho-ke ongenayo indima okufanele ayisebenze, isikhathi sezindaba ngeke sibekhona-ke. Singakhohlwa ukuzehlisa sibe ngabantwana, sihloniphane uma sifuna ukuya ezulwini ngelanga lokugcina.\n\nSinifisela unyaka onesibusiso ozayo ka-2005 nempilo enhle.\n\nYimi owenu ku-Krestu,\nN.V.Mlangeni\nChief/President''',
        },
      },
    },
    {
      'id': '2002_03',
      'year': '2002/03',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'CHIEF/PRESIDENT',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'Umbuliso WoMpostoli Kumabandla Wonke',
          'message':
              '''Bathandwa ku kristu\n\nNginilobela lombuliso nginokujabula okukhulu, nothando olumangalisyo ngani nonke bantwana baka-Thixo enathandwa yinkosi yethu u Jesu Kristu, owasifela esiphambanweni ukuze sithethelelwe ezonweni zethu. Futhi ngiloba lombuliso nginokujabula ngemisebenzi nezenzo ezinhle enizenzile kulongyaka. Ngingebale imisebenzi emibi, lapho omubi naye ekade ezama ukufaka unyawo Iwemfene emisebenzinini ka Nkulunkulu emihle kangaka.\n\nAngikholwa ukuthi ukhona noyedwa osadideka namhlanje kulenkonzo yakithi, ngoba mina ngathi kini, omubi akayithandi into enhle. Ufica abantu benkosi bemunye bedumisa, behlangene, beyinto eyodwa, afike azame ukubehlukanisa, afake nomoya wokungezwani nasezincekwini zixabane, kungabi nokuzwana.\n\nAke-ngibuze bantwana baka Thixo; Niyakujabulela yini ukubona izinceku noma izincekukazi zixabana ngenxa yakho noma yenu? Ngibuye ngize kini njengezinceku nezincekukazi; kunganijabulisa yini uma kungekho ukuthula emizini yenu, izingane zixabana zikhiphelana izikhali ezimbi? Ngabe siyakhohlwa yini ukuthi thina sathengwa ngenani eliphezulu kakhulu? Akekho namunye onemali engangaleyo eyathenga thina. Ingabe yona-ke leyo-mali eyathenga thina niyayazi? Angani phela yileligazi lenkosi u-Jesu Kristu elachitheka esiphambanweni, mhla yayifela izono zethu. Sathengwa ngalelogazi-ke. Cabangake nawe ukuthi kwakubuhlungu kangakanani kuleyondoda.\n\nAkufuneki-ke sifane nabantu abangacabangi, nabangakhathaleli izimpilo zabo, yize sahlushekelwa kangaka. Uthando olungaka esathandwa ngalo, saze sabizwa ngabathandwa ngoba sithandwe yinkosi. Bathandwa akekho noyedwa ongathi akazi ukuthi wabizelwani kulenkonzo ngaphandle kokuzosebenzela usindiso lomphefumulo wakhe nabakubo asebadlula ezweni.\n\nUthole umuntu enza izinto eziphambene nokulunga, akhohiwe ukuzithandazela. Akukho lutho olulukhuni nolusindayo kulenkozo ka-Nkulunkulu uma-nje sinjengabantwana abafundisekayo, nabagcina imithetho yakhe. Sibe umhlaba owamukela amanzi aqhamuka e Tronini (Throne), ngalemifula emithathu. Yini I-Troni (Throne)? Engani phela ngu Mpostoli loyo uqobo Iwakhe, lapho kukhona konke okuphilisayo. Lemifula emithathu-ke yona yini na? Owokuqala ngumelusi uMveleli, owesibili ngumvangeli, owesithathu ngu Mprofethi.\n\nLalelake mthandwa: Umvangeli uyabalanda ehlabathini ngothando nangoxolo abalethe ezulwini, bese beluswa ngothando nangeqiniso nguMelusi, bese bexwayiswa ngu mprofethi. Bayazi inaawo abakuyona ukuthi iphephe kangakanani, nokuthi yini u-Nkulunkulu ayilindele ebantwini bakhe ukuthi bayenze. Nengozi ekhona nezayo bayaziswe ngu Mprofethi. Uma kuyinto enhle umgcotshwa noma umelusi ayivulele, kodwa uma kuyinto embi umelusi uphiwe amandla okuyivala ukuthi ingenzeki.\n\nBathandekayo enkosini, ungabona-ke ngokungokwakho ukuthi uNkulunkulu usithandla kangakanani. Kungakho ethi: yilelo nalelo bandla elingenawo umoya wesi-profetho lifile kanye nemisebenzi yalo.\n\nBathandwa, nginifisela izibusiso nokuphila okuhle kulonyaka omusha nemindeni yonke yenu. Khanyani bantwana bokukhanya. Masiwugoge unyaka omdala ka-2002 nezigameko zawo, sixolelane kukho-konke esiphosiselene ngakho, singene sonke sibasha ku 2003, sesilahle wonke ama-vukuvuku amadala. Sishise wonke ama almanaka (Calenders), nezincwadi ezindala sihloniphane, sithandane, sibekezelelane, siyeke nokubukelana phansi.\n\nPhansi ngamacala! Phansi ngezindaba! Phenzulu ngemisebenzi! U-Nkulunkulu anibusise.\n\nYimi owenu ku-Krestu\nNV MLANGENI\nCHIEF/PRESIDENT''',
        },
      },
    },
    {
      'id': '2001_02',
      'year': '2001/02',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'Chief Apostle / President',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'en': {
          'title': '2001 - 2002 FESTIVE GREETINGS',
          'message':
              '''Beloved in the Lord,\n\nI greet you all in the name of our Lord Jesus Christ. I want to thank you all for your perseverance in the out going year, I know some of you went through many unpleasant situations, but, through perseverance you were able to overcome all that, through our Lord Jesus Christ and our officers whom we are blessed with by our living apostle. Let us praise the Lord again in the new coming year of 2002, beloved, we have seen the good fruits of the teachings of childhood. We learn about the disciples of Jesus Christ who at one time approached the Lord and asked him a question and said, "Lord : who is the greatest in the kingdom of heaven?"\n\nWe learn that Jesus called a little child unto him and set him in the midst of them, and said, verily I say unto you, except ye be converted, and become as little children, ye shall not enter into the kingdom of heaven. Whosoever therefore shall humble himself as this little child, the same is greatest in the Kingdom of heaven. My beloved, I call unto you all let us not dispise the word that comes from above, because if we dispise and criticize the officers given to us by the living apostles we shall be decreasing our blessings. Blessed are those who humble themselves as little children for they will be uplifted on their last days.\n\nMy dear brother and sisters, let us learn to forgive those who trespass against us so that we can also be forgiven our trespasses one day by the Lord.\n\nI want to wish you all well in the new year, may God Almighty through his son Jesus Christ and living apostles pour his blessings and better life to all of you and your families.\n\nYour humble servant\nN.V. MLANGENI\nChief Apostle / President''',
        },
      },
    },
    {
      'id': '2000',
      'year': '2000',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'U Mpostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title':
              'KUMABANDLA WONKE ENKONZO YABA - POSTOLI ABALISHUMI NAMBILI KU-KRISTU',
          'message':
              '''Bathandwa ku-Kristu, ngiyanibingelela.\n\nNjengoba nazi nonke ukuthi u Thixo, usinike, izingonyama, wasinika futhi neziqu ezine, nezinyanga, namanesi, naba Pristi kanjalo nabashumayeli: Wasihlanganisa u Thixo wasibopha ngothando Iwakhe wasenza saba yiketango (chain) legolide ekufanele ukuthi libe yindingilizi (ring) ukuze bonke abantwana bakhe bahlale phakathi kwayo bavikeleke ezintweni ezinobungozi, nezimbi zelizwe.\n\nKuyadabukisa ukuzwa ukuthi kusekhona abanye abafowethu nodadewethu esithi sikhonza, sidumisa inkosi yethu nomsindisi, bona babe besagqugquzela iziteleka (strikes) enkonzweni yethu enhle kangaka, nesiyithanda kangaka. Bafake imimoya engalunganga, emibi kwamanye amalunga Kulomzimba ka-kristu, ukuthi kungabikhona ukuthula enkonzweni, okufunwa yinkosi. Badale ukuvukelana enkonzweni, ukuhloniphana kuphele, kanti kuhle ukuthobelana.\n\nBathandwa ngasho kaningi phakathi kwenu ngathi, ukuhlakanipha kuyaphela, kepha ubilima abupheli. Umuntu ngalesikhathi ezibona ukuthi yena uhlakaniphile kunabanye, yilapho-ke bunqala khona ubu-phukuphuku bakhe.\n\nBathandwa ngiyanibonga ngobunqutho benu enibutshengisile kulonyaka ofayo. Kubekhona izinto ezinhle nezimbi futhi; esihlangabezane nazo kulendiela, kodwa sizehlulike ezimbi saziphilisa ezinhle.\n\nNgicela ukuthi nigabulalani bathandwa, ngokufakana ekulingweni, kanjani na? Ngokuthi kufike omunye undadewenu noma umfowenu kuwe akutshengise ububi bomuye umfowenu noma udadewenu, noma benceku emphambi kwakho, moma athi kuwe "asiyivukele lenceku". Yazi kahle kamhlophe ukuthi usuvukela u Thixo uqobo-Iwakhe ngokwenzenjalo. Uma kukhona indaba phakathi kwenu nobabili, hlalani phansi niyilungise. Angeke inga pheli leyonkinga ngoba ninomya ka Thixo nobabili niyathobelana.\n\nNgenani-ke batwnana baka-Baba ngokubusiseka okukhulu onyakeni omusha ka 2001. Nihlephule isinkwa ngaso sonke isikhathi ngisho noma uwendwa uzihlephulele, ukuze ingozi yobumnyama ingakwazi ukungena phakathi kwenu inidunge.\n\nUnkulunkulu asisize siwakhe lomzimba owodwa ka-kristu, ukuze thina sibe ngamalunga kuwona asebenzisana ngkuzwana. Kanjalo nenhliziyo eyodwa ezokwazi, uku-pompa igazi eliyofinyelela kuwo wonke amalunga ukuze wonke aphile, siyibonge inkosi eluthando simunye.\n\nInkosi inibusise nonke kanye nemindeni yenu.\n\nYimi Owenu\nNV Mlangeni\nU Mpostoli''',
        },
      },
    },
    {
      'id': '1999',
      'year': '1999',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'CHIEF APOSTLE/PRESIDENT',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'en': {
          'title': 'Greetings to all congregations',
          'message':
              '''Beloved in the Lord,\n\nI greet you all in the name of our Lord Jesus Christ, for our saviour once said to his followers, I call you beloved, because you are being loved by God, who created heaven and earth through love and created birds and animals through love, and lastly he created man in his own image, also through love where then at the end, when God finished creating, he sent his begotten son Jesus Christ who was born alone to come to earth and die for only those who believed that he came from heaven and sent by his father, for the world did not believe in him and they called him by names instead. But those who accepted hira as Lord and Saviour and carried their crosses and followed him were called Christians for they followed Christ on his golden foot steps.\n\nBeloved in the Lord we all know how our Lord Jesus Christ suffered on earth until the day of his crucifixior through us, but he conquered the death througu perseverance and also by being honest to God his father. Our sins were then forgiven. After the forgiveness of our sins the Lord Jesus Christ made us to be the joints of his body and we had all the right to be called the children of God.\n\nBeloved Jesus Christ once said to his disciples, "My father is the gardener and I am the vine, you are the branches on this vine which is me, every branch that bears no fruit will be removed and thrown outside the vineyard and it will become dry, and it will be picked up by those who are in need of firewood and they will make fire thereof."\n\nMy beloved brothers and sisters, officers and sisters, as we now all understand that we are the joints on this body of Christ, let us bring this to our attention that Christ is the head who had risen from the dead. Likewise we have also risen from the dead. We have become life so that we can now go forth and save others.\n\nI want to thank every one of you for having enough patience and to be so supportive to us in the difficult and heavy task to preach evangelism of love and peace. We have encountered many things on the way of this outgoing year. Some were painful and some were like jokes, but God is great, we are taught always that we must thank our Lord always for things that we encounter. We all know that even a person who does not believe in God, when he is in trouble, will always say "Oh, my God". That shows us that misery can bring you nearer to God, and likewise pleasure can also make us forget about our enemies.\n\nLet us also be careful about things that we utter, because our mouths can cause disaster between God and ourselves. We are facing difficult times, beloved, where the devil is also clothed in white like the children of God so that he cannot be noticed easily, but the spirit of God will always reveal itself to you, only if you keep his four commandments, namely:-\n\n1. Keep time of all your services.\n2. Offer your tithes (materially).\n3. Offer your tithes (spiritually), and\n4. Love thy neighbour, inside the church and outside the church.\n\nWe are looking forward to entering the year 2000, which I say is going to be a year of blessings. Let us not forget to respect our officers, for they are our fountains that are opened by us. Let us not dirty them for tomorrow you will become thirsty and think of the water you once drank, and once you think of the dirty things you did to the fountain, you will feel bilious and you will die of thirst. Remember my beloved, respect is your key to open, and love is your weapon to conquer in the new year 2000.\n\nGOD BLESS YOU ALL.\n\nYours in Christ\nN.V. MLANGENI\nCHIEF APOSTLE/PRESIDENT.''',
        },
      },
    },
    {
      'id': '1996_97',
      'year': '1996/97',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'UMPOSTOLI',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'UMBULISO WOMPOSTOLI KUMABANDLA ONKE',
          'message':
              '''BATHANDWA KU KRESTU,\nNGINILCUELA LOMBULISO NGINOKUJABULA OKUKHULU NOTHANDO OLUMANGALISAYO NGANI NONKE ZANTWANA ΠΑΚΑ ΤΙΧΟ ENATHANDWA INKOSI YETHU UJESO KRESTE, OWASIFELA ESIPHAMDANWENI UKUZE SITHETHELELI EZONWENI ZETHU, FUTHI NGILOEA LOMBULISO NGINOKUJASULA NGOMSEBENZI NEZENZO EZINHLE ENIZENZILE KULONYAKA. SIPHINDE FUTHI SIMDUMISE UMDALI, NE NKOSI YETHU UJESO KRESTU KUKO KONKE ASENZELELE KONA KULONYAKA ΚΑ 1996.\n\nNGIQINISILE UKUTHI UMA SINGADALA IZINTO NEZENZO EZINHLE NEZIMBI EZISIVELELE THINA KULENKON 20, SINGATHOLA UKUTHI KUNINGI NAGAPHEZULU OKUHLE NCKUTHOKOZISAYA KUNALOKHO: OKUPI NOKUJABISAYO UTHIXO ASENZELA KONA. NGEMPELA UTHIXO UΓΕΝΑΤΗΙ KULONYAKANENGADANTWANA SAKHE, YEBO ADANYE BALAHLEKELWA IMINDENI NEZIHLODO ZADO, KONKE LOKHO KWALA ISIFUNDO NAKUTHINA UKU UMA UMOYA OMULI UVUNGUZA WEMUKA NABANTU NGOBA ADANTU AFANYE DASUKE EXHOSWE IZINTULI ZOMOYA BESE BETHATHA INDLELA ADANGADIZELWANGA UKUTHI BAHAMDE NGAYO UKUZA KU THIXO BESEDAYALAHLEKA, DAZITHOLE SEDE KWENYE INDAWO UTRIXO ANGALAI IZELANGA KUYONA.\n\nΚΑΝΤΙ ΚΕ MINA NJE NGOMPOSTOLI NGIFISA UKUDONGA KAKHULU EZINCEKWINI ZONKE NAKUBAZALWANE NODADE NGOKUBAMBISANA NAMI KUWO UMSELENZI WOKWAKHA INDLU KA THIXO. KUBE KUKHULU KAKHULU UKUDAMBISANA NOKUZINIKELAKWENU. UNKULUNKULU MAKANIQINISE KULESISENZO ESINCOMEKAYO. NALALO ANAHLALELE IZIZATHU NOKUGXEKA NOKUDILIZA, ANIBAVUMELANGA. YINGAKHO IZINJONGO NEZIFISO ZABARIDLIZI ZINGAPHUMELANGA..\n\nBATHANDWA NGINIFISELA. UNYAKA KA 1997 UDE YIMPUMELELO KINI NADANTWANA BENU, UNIMQODE CMUDI MHLAMDE EKUKHANYENI SISEBENZELE UMDALI, SINGAKHOHLWA NGADAZALI DETHU. UTHIXO ANIPHE AMANDLA OKUSITHWALA ISIPHAMDANO SENU M, ANJE KUZE KUDE SEKUNQOLENI NGENKOSI YETHU UJESC KRESTU. AMEN.\n\nOWENU ENKOSINI\nN.V. MLANGENI (UMPOSTOLI)''',
        },
      },
    },
    {
      'id': '1995_96',
      'year': '1995/96',
      'apostle': 'Apostle N.V. Mlangeni',
      'role': 'UMPOSTOLI',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'THE TWELVE APOSTLE\'S CHURCH IN CHRIST',
          'message':
              '''BA THANDEKAYO KUKRESTU:\n\nNgiyanibulisa egameni lenkosi yethu uJesu Krestu. Ngomusa Nothando luka Thixo uMdali wethu, sesiyawuqoqa unyaka ka1995 maduzane nje. Kepha ke thina siyaqonda ukuthi inkosi yethu yethu uJesu wahlushwa waza wabulawa ngenxa yethu. Kodwa ke wakunqoba ukufa ngenxa yokubekezela nokwethemba kuThixo uyise saze sathola ukuthethelelwa nathi ezonweni zethu. Sesithethelwa uKrestu wasenza saba amalunga omzimba wakhe saba nelungelo lokubizwa ngokuthi singabantwana baka Thixo. Njengamalunga ke omzimba kisho ukuthi intloko yethu uKrestu owavuka ekufeni, nathi ke sesivukile ekufeni saba yimpilo ekufanele ukuthi nathi nathi siyophilisa abanye phela.\n\nNgiyanibonga kakhulu ngokubekezela kwenu nasekubambisaneni nathi kulo msebenzi obucayi kangaka wukuqhuba ivangeli lokuthula noxolo ziningi ke izinto enihlangabebezene nazo kulo nyaka odlulile, ezinye zibuhlungu, ezinye zihlekisa, ukuba kwakusezweni kwakufanele ukuthi siphathwe ngo HIGH BLOOD PRESSURE kunye noSUGAR DIABETICS, kodwa okuka Thixo kuyamangalisa. Kodwa ke sifunda ukuthi kufanele siyibonge iNkosi umdali wethu ngazo zonke izinto ezisehlelayo.\n\nUTHIXO ANIBUSISE NONKE KULONYAKA KA-1996 OZAYO.\n\nOwenu kuKrestu\nNV MLANGENI (UMPOSTOLI)''',
        },
      },
    },
    {
      'id': '1990s_pakathi_1',
      'year': '1990s',
      'apostle': 'Apostle S.D. Pakathi',
      'role': 'uMpostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'KUWO WONKE AMABANDLA ENKONZO YABAPOSTOLI',
          'message':
              '''Bathandwa kukrestu,\n\nNizokhumbula ukuthi ngonyaka odlule nginibhalele ngenxa yesima esasibucayi ngenxa yenxushunxushu eyayihlasele isizwe sikaTixo. Ukunilobela kwami kwakungenxa yokuba nginifisela impilo enhle nezibusiso. Ngakhoke kwakudingekile ukuba nginivikele kulabo ababenidida izingqonda zenu.\n\nBathandwa njengoba sengishilo ngasenhla mangisho ukuthi ngiyabonga nonke nina enangemukelayo njengenceku nesisebenzi senu kukrestu Jesu. Kungumthandazo wami ukuba ngisebenzisane nani ngendlela etusekayo kini nonke nakuTixo umdali. Kodwa konke lokho kungenzeka ngoba sibambene nani njengoba senibutshengisile ubuqotho benu. Bathandwa, unyaka odlule uthe uma usuphela wasizela nobuhlungu nezingqinamba eziningi noba kunjalo sabambelela kumdali. Asifanele neze ukuba sikhohlwe izimfundo esabe sinikwe ubaba uMpostoli. Futhike bathandwa ngiyanicela nonke ukuba sibe naye ubaba wethu lapho ekhona ngezinhliziyo nangemithandazo yetnu.\n\nBathandwa ngingeze ngaxola ngempela uma nginganibonganga ngomsebenzi wenu omkhulu eniwenzile wokuvikela nokuma nezinceku zenu. Ngikhuleka kuTixo umdali wethu ukuba angenze ngibe phakathi kwenu ngamsebenzi engithunywe ngawo kini maduze nje. UTixo ubaba uyasambulela yena ukuba lonyaka usiphatheleni utixo. Anibusise nonke.\n\nYimi isisebenzi senu,\neNdlini ka Krestu,\nD. PAKATHI: uMpostoli''',
        },
      },
    },
    {
      'id': '1990s_pakathi_2',
      'year': '1990s',
      'apostle': 'Apostle S.D. Pakathi',
      'role': 'UmPostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'KUMABANDLA ONKE ENKONZO YABA POSTOLI',
          'message':
              '''Bathandwa kukrestu,\n\nNjengoba nazi nonke ukuthi uTixo usinike izingonyamá ezimbili kule nkonzo yethu esiyithandayo, lapha ubaba umPostoli Ndlovu eyinhloko khona. Nanjengoba nazi futhi ukuthi ubaba umPostoli Ndlovu wahamba ngomsebenzi wakhe awubizelwa uTixo waya eMaputo. Nanjengoba nazi ukuthi ubaba umPostoli Ndlovu mhla ebeka mina mPostoli Pakathi, wakubeka ngokusobala ukuthi awukho umngcele ongumehlukaniso kimi naye. Wakubeka ukuthi sisebenza sonke naye ngokufana.\n\nNgicela sikhumbule sonke ukuthi, umPostoli wathi asihlale lapho sikhokhelwa khona, sihambe ngokulandelana singashayisani. Ngakhoke uma simthanda umPostoli wethu angiboni ukuthi kukhona ongasusa omunye lapho ekhokhelwa khona. Asiphinde sikhumbule ukuthi umPostoli usihlanganisile wasakha sabamzimba munye, namalunga emzimbeni kakrestu. Lowoke oyilunga ngempela lalomzimba kakrestu ufanele ezwe ubuhlungu uma ilunga lahlukaniswa nelinye ngemimoya.\n\nNgiyaphinda ngithi uma simthanda umPostoli Ndlovu ongubaba wethu sonke asingamukeli izinqumo ezisahlukanisayo. Ukuze kubekhona uxolo nokuthula engabizelwa khona ngithathe lelithuba lokunazisa ukuthi bonke abaveleli basebenza njengoba umPostoli wabashiya nihlale kubo. Ngiyanibonga ngokungamukela kwenu njengesisebenzi senu.kukrestu. uTixo anigcine anibusise nonke.\n\nYimi owenu eNkosini\nS.D. PAKATHI\n(UmPostoli)''',
        },
      },
    },
    {
      'id': '1977',
      'year': '1977',
      'apostle': 'Apostle J.S. Ndlovu',
      'role': 'U Mpostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'KUWO WONKE AMABANDLA E AFRICA (11 DEC 1977)',
          'message':
              '''Bathandwa ku Kristu,\n\nNgifisa ukuphinda futhi nginibonge kanye namabandla onke, njokuma kanye nani eninyakeni eyedlule. Besitotoba sonke kanye kanye sibambene kungekho ozenzelayo nongalaleli.\n\nNingofakazi nina ngokwenu ngokuthi ozenzelayo ulinyazwa yiko loko azenzela kona yena ngokwakhe kodwa owenza ngendlela alayelwa ngayo uphilile kufinyelela kuleli langa.\n\nInkonzo yethu se isezingeni eliphakene Kakhulu nanje ngenxa yemisebenzi emihle phakathi kwenu. Kuyisifiso sami ukuba nikhule nayo inkonzo kungabikho owenza okwehlukene nabanye, ngoba ngokwenzenjalo uyobe uyadiliza.\n\nU musa ka Baba ube nani njalo njalo.\n\nYimina,\nOwenu o Nkosini,\nJ. S. Ndlovu.\nU Mpostoli.''',
        },
        'en': {
          'title': 'TO ALL CONGREGATIONS IN AFRICA (11 DEC 1977)',
          'message':
              '''Beloved in Christ,\n\nI wish to thank you again along with all the congregations, standing with you as in the past year. We moved forward all together, united, with no one acting on their own and disobeying.\n\nYou are witnesses yourselves that the one who acts on their own is harmed by what they do to themselves, but the one who does as instructed is well up to this day.\n\nOur church is now at a very high standard because of the good works among you. It is my wish that you grow with the church with no one doing things differently from others, because by doing so you will be destroying.\n\nThe grace of the Father be with you always.\n\nI am,\nYours in the Lord,\nJ. S. Ndlovu.\nApostle.''',
        },
      },
    },
    {
      'id': '1975_76',
      'year': '1975/1976',
      'apostle': 'Apostle J.S. Ndlovu',
      'role': 'U Mpostoli',
      'image_url': 'assets/profile_placeholder.png',
      'content_json': {
        'zu': {
          'title': 'THE TWELVE APOSTLES CHURCH IN AFRICA',
          'message':
              '''Bathandwa eNkosini,\n\nBekuphinde kwafika isikhathi futhi lapha sifanele sibambisane ukudumisa iNkosi ngazwi linye, ngenxa. yezibusiso zayo kunyaka ophelayo. Ngiyanibonga nonke futhi bakwethu ngokuhlala kwenu emilayezweni ka Thixo, nangokwenza nge ndlela ilizwi lakhe elinilayeza ngakhona.\n\nKhumbulani uNkulunkulu uloku esisingethe njalo kanye nabantwa. bethu. Akuyiko yini okokubongwa loko na? Yiko. Ukubonga nokudumisa uNkulunkulu ke akuyiko ukuya enkonzweni nje kuphela nokuhlephula isinkwa ngokwesighelo, kodwa.. kuhlangene ne nrumbulo njalo njalo ngaphakathi komuntu.\n\nHLEPHULA ISINKNA NOMA UWEDWA LAPHO UKHONΝΑ. IKAKHULU UMA KUNGEKHO LUTHO OLWENZAYO NGALESO SIKHATI, UKUZE OMUBI ANGAKUFUMANI UDINGA. AZE AKWABELE OWAKHE UNSEBENZI.\n\nUyosigcina njalo kuze kusinde nabaningi ngerxa yethu. Mayande oka Thixo intande kunyaka ongenayo.\n\nYinina,\nOwenu eNkosini,\nJ. S. Ndlovu.\nU Mpostoli.''',
        },
      },
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchDatabaseGreetings();
  }
 
  Future<void> _fetchDatabaseGreetings() async {
    setState(() => _isLoadingDB = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final url = Uri.parse(
        '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/',
      );
      final res = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() => _dbGreetings = jsonDecode(res.body));
      }
    } catch (e) {
      print("Error fetching: $e");
    }
    setState(() => _isLoadingDB = false);
  }

  // 2. BULK UPLOAD (Submits all massive array data)
  Future<void> _uploadAll() async {
    setState(() => _isUploading = true);
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();

    final url = Uri.parse(
      '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/',
    );

    for (int i = 0; i < _staticGreetingsData.length; i++) {
      try {
        await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(_staticGreetingsData[i]),
        );
      } catch (e) {
        print("Upload Error: $e");
      }
    }
    setState(() => _isUploading = false);
    _fetchDatabaseGreetings();
    Api().showMessage(
      context,
      "Success",
      "Greetings Bulk Uploaded!",
      Colors.green,
    );
  }
 
  void _openEditDialog(Map<String, dynamic> greeting) {
    String selectedLang = 'en';
    TextEditingController titleCtrl = TextEditingController();
    TextEditingController messageCtrl = TextEditingController();

    Map<String, dynamic> contentJson = greeting['content_json'] is String
        ? jsonDecode(greeting['content_json'])
        : greeting['content_json'];

    void updateFieldsForLang() {
      if (contentJson[selectedLang] != null) {
        titleCtrl.text = contentJson[selectedLang]['title'];
        messageCtrl.text = contentJson[selectedLang]['message'];
      } else {
        titleCtrl.clear();
        messageCtrl.clear();
      }
    }

    updateFieldsForLang();
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.05),
      theme.scaffoldBackgroundColor,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: neumoBaseColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Manage: ${greeting['year']}",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 20),

                  // UPLOAD IMAGE BUTTON
                  GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final pickedFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                      if (pickedFile != null) {
                        try {
                          final file = File(pickedFile.path);
                          final ref = FirebaseStorage.instance.ref().child(
                            'apostle_photos/${DateTime.now().millisecondsSinceEpoch}.jpg',
                          );
                          await ref.putFile(file);
                          final downloadUrl = await ref.getDownloadURL();

                          final user = FirebaseAuth.instance.currentUser;
                          final token = await user?.getIdToken();
                          final url = Uri.parse(
                            '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${greeting['id']}/',
                          );
                          await http.patch(
                            url,
                            headers: {
                              'Authorization': 'Bearer $token',
                              'Content-Type': 'application/json',
                            },
                            body: jsonEncode({'image_url': downloadUrl}),
                          );
                          Api().showMessage(
                            context,
                            "Success",
                            "Image updated!",
                            Colors.green,
                          );
                          _fetchDatabaseGreetings();
                          Navigator.pop(context);
                        } catch (e) {
                          print("Upload failed: $e");
                        }
                      }
                    },
                    child: NeumorphicContainer(
                      color: theme.primaryColor,
                      isPressed: false,
                      borderRadius: 15,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "Upload Photo",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),
                  Divider(color: theme.primaryColor.withOpacity(0.2)),
                  SizedBox(height: 10),

                  Text(
                    "Translations",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 10),

                  // LANGUAGE DROPDOWN
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: true,
                    borderRadius: 15,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: selectedLang,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          color: theme.primaryColor,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text("English")),
                          DropdownMenuItem(
                            value: 'nso',
                            child: Text("Sepedi (Northern Sotho)"),
                          ),
                          DropdownMenuItem(value: 'st', child: Text("Sesotho")),
                          DropdownMenuItem(value: 'zu', child: Text("isiZulu")),
                          DropdownMenuItem(
                            value: 'xh',
                            child: Text("isiXhosa"),
                          ),
                          DropdownMenuItem(
                            value: 'ts',
                            child: Text("Xitsonga"),
                          ),
                        ],
                        onChanged: (val) {
                          setDialogState(() {
                            selectedLang = val!;
                            updateFieldsForLang();
                          });
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  // TITLE INPUT
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: true,
                    borderRadius: 15,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: titleCtrl,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Title in selected language",
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  // MESSAGE INPUT
                  NeumorphicContainer(
                    color: neumoBaseColor,
                    isPressed: true,
                    borderRadius: 15,
                    padding: EdgeInsets.symmetric(horizontal: 15),
                    child: TextField(
                      controller: messageCtrl,
                      maxLines: 5,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "Message in selected language",
                      ),
                    ),
                  ),

                  SizedBox(height: 25),

                  // ACTION BUTTONS
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: NeumorphicContainer(
                            color: neumoBaseColor,
                            isPressed: false,
                            borderRadius: 15,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Center(
                              child: Text(
                                "Cancel",
                                style: TextStyle(
                                  color: theme.hintColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            contentJson[selectedLang] = {
                              'title': titleCtrl.text,
                              'message': messageCtrl.text,
                            };
                            final user = FirebaseAuth.instance.currentUser;
                            final token = await user?.getIdToken();
                            final url = Uri.parse(
                              '${Api().BACKEND_BASE_URL_DEBUG}/apostolic_greetings/${greeting['id']}/',
                            );
                            await http.patch(
                              url,
                              headers: {
                                'Authorization': 'Bearer $token',
                                'Content-Type': 'application/json',
                              },
                              body: jsonEncode({'content_json': contentJson}),
                            );
                            _fetchDatabaseGreetings();
                            Navigator.pop(context);
                          },
                          child: NeumorphicContainer(
                            color: theme.primaryColor,
                            isPressed: false,
                            borderRadius: 15,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            child: Center(
                              child: Text(
                                "Save",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      theme.primaryColor.withOpacity(0.05),
      theme.scaffoldBackgroundColor,
    );

    return Scaffold(
      backgroundColor: neumoBaseColor,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            Text(
              'Admin: Greetings Setup',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: theme.primaryColor,
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 20),

            // NEUMORPHIC TAB SWITCHER
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 0),
                      child: NeumorphicContainer(
                        color: _selectedTabIndex == 0
                            ? theme.primaryColor
                            : neumoBaseColor,
                        isPressed: _selectedTabIndex == 0,
                        borderRadius: 30,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            "Bulk Upload",
                            style: TextStyle(
                              color: _selectedTabIndex == 0
                                  ? Colors.white
                                  : theme.hintColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTabIndex = 1),
                      child: NeumorphicContainer(
                        color: _selectedTabIndex == 1
                            ? theme.primaryColor
                            : neumoBaseColor,
                        isPressed: _selectedTabIndex == 1,
                        borderRadius: 30,
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Center(
                          child: Text(
                            "Manage DB",
                            style: TextStyle(
                              color: _selectedTabIndex == 1
                                  ? Colors.white
                                  : theme.hintColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // TAB CONTENT
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildBulkUploadTab(theme, neumoBaseColor)
                  : _buildManageDbTab(theme, neumoBaseColor),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: BULK UPLOAD UI
  Widget _buildBulkUploadTab(ThemeData theme, Color baseColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: NeumorphicContainer(
          color: baseColor,
          isPressed: false,
          borderRadius: 25,
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_upload_rounded,
                size: 80,
                color: theme.primaryColor.withOpacity(0.8),
              ),
              SizedBox(height: 20),
              Text(
                "Submit 40 Years of Historical Data\n(Initial Setup)",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              SizedBox(height: 40),
              _isUploading
                  ? CircularProgressIndicator()
                  : GestureDetector(
                      onTap: _uploadAll,
                      child: NeumorphicContainer(
                        color: theme.primaryColor,
                        isPressed: false,
                        borderRadius: 30,
                        padding: EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        child: Text(
                          "Submit To Database",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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

  // TAB 2: MANAGE DB UI
  Widget _buildManageDbTab(ThemeData theme, Color baseColor) {
    if (_isLoadingDB) {
      return Center(child: CupertinoActivityIndicator(radius: 15));
    }

    if (_dbGreetings.isEmpty) {
      return Center(
        child: Text(
          "No greetings found in database.",
          style: TextStyle(color: theme.hintColor),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: BouncingScrollPhysics(),
      itemCount: _dbGreetings.length,
      itemBuilder: (context, index) {
        final item = _dbGreetings[index];

        String imgUrl = item['image_url'] ?? 'assets/profile_placeholder.png';
        bool isNetworkImg = imgUrl.startsWith('http');

        return Padding(
          padding: const EdgeInsets.only(bottom: 15.0),
          child: NeumorphicContainer(
            color: baseColor,
            isPressed: false,
            borderRadius: 20,
            padding: EdgeInsets.all(15),
            child: Row(
              children: [
                NeumorphicContainer(
                  color: baseColor,
                  isPressed: true,
                  borderRadius: 30,
                  padding: EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: theme.primaryColor.withOpacity(0.1),
                    backgroundImage: isNetworkImg
                        ? NetworkImage(imgUrl) as ImageProvider
                        : AssetImage(imgUrl),
                    onBackgroundImageError: (e, s) {},
                    child: isNetworkImg
                        ? null
                        : Icon(Icons.person, color: theme.primaryColor),
                  ),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${item['apostle']} - ${item['year']}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Langs: ${(item['content_json'] is String ? jsonDecode(item['content_json']) : item['content_json']).keys.join(', ')}",
                        style: TextStyle(color: theme.hintColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _openEditDialog(item),
                  child: NeumorphicContainer(
                    color: baseColor,
                    isPressed: false,
                    borderRadius: 15,
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
