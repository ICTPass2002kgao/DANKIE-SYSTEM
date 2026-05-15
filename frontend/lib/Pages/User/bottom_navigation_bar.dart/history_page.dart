import 'package:flutter/material.dart';
import 'package:ttact/Components/NeuDesign.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  // This variable will control whether the history text is visible.
  // Set it to `true` when you want to make the text available.
  final bool isContentAvailable = false;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context);
    final Color neumoBaseColor = Color.alphaBlend(
      color.primaryColor.withOpacity(0.08),
      color.scaffoldBackgroundColor,
    );

    return Container(
      alignment: Alignment.topLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: neumoBaseColor,
      child: isContentAvailable
          ? SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Center(
                    child: NeumorphicContainer(
                      child: Text(
                        "TACT",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 30,
                          color: color.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle(
                    """  The Twelve Apostles Church In Christ History
                
                1832 - First Apostle J.B. Cardale
                1835 - Catholic Apostolic Church founded
                1852 - C.G. Klibbe was born in December
                1889 - Apostle H.F. Niemeyer sent evangelist Carl Georg Klibbe to South Africa
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
                As Christians we all know that Jesus Christ is Lord, and that he has universal
                divine authority. Matthew says "all authority has been given to him on heaven
                and earth." [ Mt.28.18.] The Father placed everything into his hands.[Jhn.3.35. ]
                His authority has been given to him by the Father in heaven. [ Lk. 10.22.]
                
                Let us remember that Jesus knew that he couldn't stay on earth forever. We
                learn from his teachings how he intended his ministry to be continued on earth.
                He chose twelve men and he called them his Apostles. So they could lead the
                church with power and authority Jesus gave them a share in his own divine
                authority. 
                Jesus says the Apostles are sent just like the Father sent him. [ John.
                20.21 ]. They are to speak the truth with the same kind of authority Jesus had,
                because Jesus says whoever listens to them listens to Him. [ Lk.10.16. ] 
                In Jn.20.23. he specifically gives them his authority to forgive sins. Jesus must have
                intended his ministry to continue because in Matthew 28.20 he promises to be
                with the apostles until the end of time. Then in John's gospel he promises the
                Holy Spirit to help with the work of understanding the Truth, [ John 16.13. ] and
                he says the Holy Spirit will remain with The Apostles forever. [John 14.16. ]
                This ministry was brought to us in Southern Africa by Evangelist Carl Geog
                Klibbe in 1889. He was commissioned by Apostle H.F.Niemeyer from
                Queensland in Australia. Since Evangelist Klibbe depended upon farming for his
                livehood, when he landed in Cape Town in 1889 he purchased a small holding at
                Bellvile, but later moved to Worcester because he could only speak german. He
                started his ministry by mainly focusing on german speaking community.
                His testimony started bearing fruits in 1892 when an embryo congregation
                emerged in Southern Africa for the first time. In 1901 a shoe maker by the name
                of Georg Heinrich Schlaphoff and his family, also emigrants from Germany
                visited the congregation. Schlaphoff was deeply impressed by the testimony and
                before long he was adopted together with his family. They were sealed by
                Apostle Carl Klibbe on Pentacost 1902. Brother Schlaphoff made a huge impact
                and was highly dedicated to the work of the Lord. He later moved to Cape Town
                to spread the Word there.
                The divine services held in the lounge of Evangelist Schlaphoff were soon well
                purchased. Here the first Church Hall was built and was dedicated by Apostle
                Klibbe on Pentacost, 4 June 1906.
                The sad division between Apostle Klibbe and Evangelist Schlaphoff began in
                Cape Town in 1910. The exact reason for this remains disputed. This went on
                until there was a division among church members. The situation worsened after
                Schlaphoff was ordained an Apostle in Germany, and there were two groups in
                the church. This confusion and bitter conflict was settled in a court hearing on 26
                December 1926. The court ruling was that Apostle Klibbe was to carry on his
                duties as "The Old Apostolic Church" and Apostle Schlaphoff retained "The New
                Apostolic Church" name.
                Apostle Klibbe carried on with his ministry as "The Old Apostolic Church" and the
                church saved many souls. This made it necessary for the Lord to bless him with
                more Aposties until the days of Apostle F.W.Nino. Apostle Nino also contributed
                towards growing the church until it had a large number of black followers. Apostle
                Nino ordained the first Black Apostle in 1953 by the name of Samuel Hlatshwayo.
                Apostle Hlathwayo passed away in 1961 and Apostle Nino ordained Apostle
                J.S.Ndlovu.
                After the passing away of Apostle Nino the relationship between Apostle
                J.S.Ndlovu and his white colleagues deteriorated. The root cause of this was the
                political situation in South Africa at the time the "Aparhteit", which led to a split in
                the church in 1968. Apostle J.S.Ndlovu sat quietly at his home for some time.
                The support he had was amazing. His supporters went to his home in numbers to
                encourage him to carry on with his good work. He carried on under a new name
                'The Tw e l v e Apostles Church in Africa". . Knowing very well that he stood no
                chance against his white opposition, Apostle Ndlovu decided that this matter was
                not to be resolved in court, he did not even want to be in the eyes of the public or
                authorities. He did not allow any media or any pictures of his church gatherings
                taken. He always taught his followers not to mention other people's names
                especially the Old Apostolic Church. He only encouraged his members to preach
                the gospel and nothing else. He asked his followers to peacefully leave the
                church halls belonging to the Old Apostolic Church and gave them application
                letters to use school classrooms for their services. He did this under very strict
                regulations from the authorities. He secretly visited those schools during services
                to make sure they abide by the rules of the authorities. He had to apply for
                permission to hold large open gatherings. His divine services attracted a lot of
                members, especially in the townships and countries like Botswana, Swaziland
                and Mozambique. Things were not easy in Mozambique in such a way that at
                one stage he had to conduct a service in the presence of government officials
                who had come to witness what he was doing. He came to South Africa being
                very exited because the government officials in Mozambique had been touched
                by the Holly Spirit and gave him permission to spread the gospel in Mozambique.
                After that service a lot of souls were saved and sealed in many parts of
                Mozambique. In September 1972 he ordained Apostle S.D.Phakathi in Durban.
                Apostle Ndlovu dedicated his first church hall in Meadowlands Soweto in 1977.
                In 1978 Apostle Ndlovu went with his delegation to Mozambique for a church
                service. He knew that it was not going to be a safe trip because God had already
                spoken. This became clear to everyone during the last farewell service he held at
                his new church hall in Meadowlands. During that service he spoke about things
                that had happened to him in the past and what could happen to him in future.
                That service was more like his funeral than a farewell. It was like during the last
                days of Jesus Christ when he was telling his Apostles about his journey to his
                Father in heaven. [ John 14. ] Most of those who were present and understood
                what God had sad, would not have allowed him to take that journey it they had a
                choice. With his trust in the Lord, like the Lord Jesus Christ Apostle Ndlovu was
                brave a n d went to Mozambique.
                When Apostle Ndlovu took longer than expected to return from Mozambique, The
                church members became concerned because it had been already reported in
                one of the local newspapers that he was in trouble with the authorities in
                Mozambique.
                When his delegation returned from Mozambique, Apostle Ndlovu and his wife
                were left behind. The delegation had two different reports about what had
                happened in Mozambique. One group confirmed the newspaper report that
                Apostle Ndlovu was in trouble in Mozambique. The other group said that was not
                true Apostle Ndlovu was conducting sealing services in Swaziland and would be
                coming back soon.
                The group of overseers that confirmed the newspaper report, led by overseer
                N.V.Mlangeni, who had accompanied Apostle Ndlovu to Mozambique went to
                Apostle S.D.Phakathi in Durban to report what had happened in Mozambique.
                When they returned to Johannesburg the opposition group claimed that they
                went to gossip in Durban, therefore they were expelled from the church together
                with Apostle S.D.Phakathi. This caused a lot of tension among church members
                and they were divided into two groups. Apostle S.D.Phakathi had no choice but
                to serve the Lord under a different name until Apostle Ndlovu came back. His
                followers were known as "United Twelve Apostles". Months went by with no sign
                of Apostle Ndlovu and Apostle Phakathi registered the church as "The Twelve
                Apostles Church In Christ". By the time Apostle Ndlovu came back to South
                Africa it was too difficult to merge the two churches because the relationship
                between the members was still very hostile.
                Apostle Phakathi carried on with his church, but still had great respect for Apostle
                Ndlovu, he used to call him his Father. The TACC grew at a very alarming pace
                under S.D.Phakathi because he introduced many activities in the church and was
                more focussed to the youth and the aged. He attracted people of all ages to the
                church. On top of all he was a very friendly person and everybody loved him
                especially the youth, he was their hero. The membership grew even in other
                countries like Zimbabwe, Swaziland, Lesotho, Mozambique, D.R.Congo, Malawi,
                Zambia and Botswana. The last thanksgiving ceremony that was held at Absa
                stadium in Durban in September 1991, showed how much God had blessed him.
                Absa stadium was packed to capacity, and he ordained five Apostles on that day.
                The current President of the TACC N.V.Mlangeni, Deputy President
                N.C. Khumalo, and Apostle W.Gelem were ordained on that day. Because of the
                growing membership Apostle Phakathi encouraged his members to purchase a
                farm at Umkomaas in Durban from their own m e a n s a n d h e started a
                construction of a multi-million rand church mission at Umgababa which is The
                Twelve Apostles Church in Christ head office today. Apostle Phakathi had great
                ideas for the church. He had plans to build an arena at the farm and he said the
                shape of it will make it easy, because it's already shaped like one. The farm is
                still being used for big church events today. Apostle Phakathi's passing away on
                6 Septeber1994 came as a shock to the church members and he will always be
                remembered. His funeral service was held at the farm he had purchased
                recently. More than 40 000 members came to pay their last respect to their hero.
                It was like a double blow to the already shaken church members when there was
                a division between the remaining Apostles, regarding who will be the "HEAD" of
                the church. The name "HEAD" became very popular and it upset the stomachs of
                many, especially those who came to the church to worship. The church split into
                two groups. Apostle N.V.Mlangeni was elected the new president by Apostle
                N.C. Khumalo who was the church co-ordinator at the time in 1995, and Apostle
                Khumalo was the deputy. On 29 November 1995 two groups celebrated their
                thanksgiving day at the farm but separately. Apostles C.Nongqunga and
                W.Gelem on one section of the farm with their followers and Apostles
                N.V.Mlangeni and N.C. Khumalo on the main arena of the farm with their follwers.
                This was a very heart breaking situation to witness.
                There were tears of joy and happiness when Apostle W.Gelem and his followers
                returned to the church in 1997.He was welcomed unconditionally with warm
                hearts by the Apotles N.V.Mlangeni and N.C.Khumalo and all the church
                members. This action seemed to heal the wounds of the past. Apostle W.Gelem
                really blessed the children of God with his powerful teachings, he had nothing but
                fire. He played a big role in merging the two groups to one united church with his
                powerful and divine services throughout the country and abroad. His last
                message to the church members wherever he went during his last days was
                Matthew [5.8] blessed are the pure in heart for they shall see God. Apostle
                W. Gelem was no longer a healthy man at that time and he passed away in 1998.
                His teachings are still alive todate. "Blessed are the pure in heart for they
                shall see God". 
                
                He was buried at his home yard at Tsolo in the Eastern Cape.
                Apostle Mlangeni and Apostle Khumalo continued with the testimony and the
                church membership has today grown by at least 300% in comparison to the
                membership during the days of Apostle S.D.Phakathi in 1994. 
                
                Kwazulu Natal represents a large percentage of membership. Mozambique also has a
                substantial number of membership.The firt sealing service was held in Angola in
                2006. Overseer John Mthembu does a very remarkable work in couries like
                Malawi, D.R.Congo, and Angola. The Church is growing in those countries.
                Apostle Miangeni has ordained ten Apostles up to today. In South Africa we have
                Apostles J.E.Hlongwane, J.R.Magano, D.S.Msane,S.D.Ndlovu and E.Mzamo.
                In Mozambique Apostles Ntimbane, Mthise, Bazar and the late apostles""",
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            )
          : NeumorphicContainer(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  Icon(Icons.lock, size: 64, color: color.primaryColor),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "This will be unlocked on Apostle Day",
                      style: color.textTheme.titleMedium?.copyWith(
                        color: color.primaryColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
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
