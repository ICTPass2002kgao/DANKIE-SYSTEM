import 'dart:math';

class BibleVerseRepository {
  static Map<String, String> getDailyVerse({DateTime? date}) {
    final targetDate = date ?? DateTime.now();
    
    // Create a unique integer based on the Year, Month, and Day.
    final String dateString = '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';
    final int seed = int.parse(dateString);

    final Random random = Random(seed);

    // Pick a random index based on that day's unique seed
    final int index = random.nextInt(_verses.length);

    return _verses[index];
  }
  // The Database of verses
  static final List<Map<String, String>> _verses = [
    // =========================================================================
    // CATEGORY: HOPE
    // =========================================================================
    {
      'category': 'Hope',
      'ref': 'Jeremiah 29:11',
      'text':
          'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.',
    },
    {
      'category': 'Hope',
      'ref': 'Romans 15:13',
      'text':
          'May the God of hope fill you with all joy and peace as you trust in him, so that you may overflow with hope by the power of the Holy Spirit.',
    },
    {
      'category': 'Hope',
      'ref': 'Isaiah 40:31',
      'text':
          'But those who hope in the Lord will renew their strength. They will soar on wings like eagles; they will run and not grow weary, they will walk and not be faint.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 3:3',
      'text':
          'But you, O Lord, are a shield about me, my glory, and the lifter of my head.',
    },
    {
      'category': 'Hope',
      'ref': 'Hebrews 11:1',
      'text':
          'Now faith is confidence in what we hope for and assurance about what we do not see.',
    },
    {
      'category': 'Hope',
      'ref': 'Lamentations 3:24',
      'text':
          'I say to myself, "The Lord is my portion; therefore I will wait for him."',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 71:14',
      'text':
          'As for me, I will always have hope; I will praise you more and more.',
    },
    {
      'category': 'Hope',
      'ref': 'Proverbs 23:18',
      'text':
          'There is surely a future hope for you, and your hope will not be cut off.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 31:24',
      'text': 'Be strong and take heart, all you who hope in the Lord.',
    },
    {
      'category': 'Hope',
      'ref': 'Romans 12:12',
      'text': 'Be joyful in hope, patient in affliction, faithful in prayer.',
    },
    {
      'category': 'Hope',
      'ref': '1 Peter 1:3',
      'text':
          'Praise be to the God and Father of our Lord Jesus Christ! In his great mercy he has given us new birth into a living hope through the resurrection of Jesus Christ from the dead.',
    },
    {
      'category': 'Hope',
      'ref': 'Micah 7:7',
      'text':
          'But as for me, I watch in hope for the Lord, I wait for God my Savior; my God will hear me.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 33:18',
      'text':
          'But the eyes of the Lord are on those who fear him, on those whose hope is in his unfailing love.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 147:11',
      'text':
          'The Lord delights in those who fear him, who put their hope in his unfailing love.',
    },
    {
      'category': 'Hope',
      'ref': 'Romans 5:5',
      'text':
          'And hope does not put us to shame, because God’s love has been poured out into our hearts through the Holy Spirit, who has been given to us.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 130:5',
      'text':
          'I wait for the Lord, my whole being waits, and in his word I put my hope.',
    },
    {
      'category': 'Hope',
      'ref': 'Titus 2:13',
      'text':
          'While we wait for the blessed hope—the appearing of the glory of our great God and Savior, Jesus Christ.',
    },
    {
      'category': 'Hope',
      'ref': 'Deuteronomy 31:6',
      'text':
          'Be strong and courageous. Do not be afraid or terrified because of them, for the Lord your God goes with you; he will never leave you nor forsake you.',
    },
    {
      'category': 'Hope',
      'ref': 'Psalm 39:7',
      'text': 'But now, Lord, what do I look for? My hope is in you.',
    },
    {
      'category': 'Hope',
      'ref': 'Job 11:18',
      'text':
          'You will be secure, because there is hope; you will look about you and take your rest in safety.',
    },

    // =========================================================================
    // CATEGORY: LOVE
    // =========================================================================
    {
      'category': 'Love',
      'ref': '1 Corinthians 13:4-5',
      'text':
          'Love is patient, love is kind. It does not envy, it does not boast, it is not proud.',
    },
    {
      'category': 'Love',
      'ref': '1 Peter 4:8',
      'text':
          'Above all, love each other deeply, because love covers over a multitude of sins.',
    },
    {
      'category': 'Love',
      'ref': '1 John 4:19',
      'text': 'We love because he first loved us.',
    },
    {
      'category': 'Love',
      'ref': 'John 3:16',
      'text':
          'For God so loved the world that he gave his one and only Son, that whoever believes in him shall not perish but have eternal life.',
    },
    {
      'category': 'Love',
      'ref': 'Romans 13:8',
      'text':
          'Let no debt remain outstanding, except the continuing debt to love one another, for whoever loves others has fulfilled the law.',
    },
    {
      'category': 'Love',
      'ref': '1 John 4:7',
      'text':
          'Dear friends, let us love one another, for love comes from God. Everyone who loves has been born of God and knows God.',
    },
    {
      'category': 'Love',
      'ref': 'Colossians 3:14',
      'text':
          'And over all these virtues put on love, which binds them all together in perfect unity.',
    },
    {
      'category': 'Love',
      'ref': 'John 15:13',
      'text':
          'Greater love has no one than this: to lay down one’s life for one’s friends.',
    },
    {
      'category': 'Love',
      'ref': 'Ephesians 4:2',
      'text':
          'Be completely humble and gentle; be patient, bearing with one another in love.',
    },
    {
      'category': 'Love',
      'ref': '1 Corinthians 16:14',
      'text': 'Do everything in love.',
    },
    {
      'category': 'Love',
      'ref': 'Proverbs 10:12',
      'text': 'Hatred stirs up conflict, but love covers over all wrongs.',
    },
    {
      'category': 'Love',
      'ref': '1 John 3:18',
      'text':
          'Dear children, let us not love with words or speech but with actions and in truth.',
    },
    {
      'category': 'Love',
      'ref': 'Mark 12:30',
      'text':
          'Love the Lord your God with all your heart and with all your soul and with all your mind and with all your strength.',
    },
    {
      'category': 'Love',
      'ref': 'Mark 12:31',
      'text':
          'The second is this: "Love your neighbor as yourself." There is no commandment greater than these.',
    },
    {
      'category': 'Love',
      'ref': 'Luke 6:35',
      'text':
          'But love your enemies, do good to them, and lend to them without expecting to get anything back.',
    },
    {
      'category': 'Love',
      'ref': 'Song of Solomon 8:7',
      'text': 'Many waters cannot quench love; rivers cannot sweep it away.',
    },
    {
      'category': 'Love',
      'ref': 'Psalm 143:8',
      'text':
          'Let the morning bring me word of your unfailing love, for I have put my trust in you.',
    },
    {
      'category': 'Love',
      'ref': 'Proverbs 3:3-4',
      'text':
          'Let love and faithfulness never leave you; bind them around your neck, write them on the tablet of your heart.',
    },
    {
      'category': 'Love',
      'ref': 'Galatians 5:22-23',
      'text':
          'But the fruit of the Spirit is love, joy, peace, forbearance, kindness, goodness, faithfulness, gentleness and self-control.',
    },
    {
      'category': 'Love',
      'ref': 'Romans 5:8',
      'text':
          'But God demonstrates his own love for us in this: While we were still sinners, Christ died for us.',
    },

    // =========================================================================
    // CATEGORY: TITHE & GIVING
    // =========================================================================
    {
      'category': 'Tithe',
      'ref': 'Malachi 3:10',
      'text':
          'Bring the whole tithe into the storehouse, that there may be food in my house. Test me in this," says the Lord Almighty.',
    },
    {
      'category': 'Tithe',
      'ref': 'Proverbs 3:9-10',
      'text':
          'Honor the Lord with your wealth, with the firstfruits of all your crops.',
    },
    {
      'category': 'Tithe',
      'ref': '2 Corinthians 9:7',
      'text':
          'Each of you should give what you have decided in your heart to give, not reluctantly or under compulsion, for God loves a cheerful giver.',
    },
    {
      'category': 'Tithe',
      'ref': 'Luke 6:38',
      'text':
          'Give, and it will be given to you. A good measure, pressed down, shaken together and running over, will be poured into your lap.',
    },
    {
      'category': 'Tithe',
      'ref': 'Proverbs 11:24',
      'text':
          'One person gives freely, yet gains even more; another withholds unduly, but comes to poverty.',
    },
    {
      'category': 'Tithe',
      'ref': 'Matthew 6:21',
      'text': 'For where your treasure is, there your heart will be also.',
    },
    {
      'category': 'Tithe',
      'ref': 'Deuteronomy 16:17',
      'text':
          'Each of you must bring a gift in proportion to the way the Lord your God has blessed you.',
    },
    {
      'category': 'Tithe',
      'ref': '2 Corinthians 9:6',
      'text':
          'Remember this: Whoever sows sparingly will also reap sparingly, and whoever sows generously will also reap generously.',
    },
    {
      'category': 'Tithe',
      'ref': 'Acts 20:35',
      'text':
          'In everything I did, I showed you that by this kind of hard work we must help the weak, remembering the words the Lord Jesus himself said: "It is more blessed to give than to receive."',
    },
    {
      'category': 'Tithe',
      'ref': 'Proverbs 22:9',
      'text':
          'The generous will themselves be blessed, for they share their food with the poor.',
    },
    {
      'category': 'Tithe',
      'ref': '1 Chronicles 29:14',
      'text':
          'But who am I, and who are my people, that we should be able to give as generously as this? Everything comes from you, and we have given you only what comes from your hand.',
    },
    {
      'category': 'Tithe',
      'ref': 'Matthew 23:23',
      'text':
          'You give a tenth of your spices—mint, dill and cumin. But you have neglected the more important matters of the law—justice, mercy and faithfulness.',
    },
    {
      'category': 'Tithe',
      'ref': 'Leviticus 27:30',
      'text':
          'A tithe of everything from the land, whether grain from the soil or fruit from the trees, belongs to the Lord; it is holy to the Lord.',
    },
    {
      'category': 'Tithe',
      'ref': 'Hebrews 13:16',
      'text':
          'And do not forget to do good and to share with others, for with such sacrifices God is pleased.',
    },
    {
      'category': 'Tithe',
      'ref': 'Proverbs 28:27',
      'text':
          'Those who give to the poor will lack nothing, but those who close their eyes to them receive many curses.',
    },
    {
      'category': 'Tithe',
      'ref': 'Mark 12:43-44',
      'text':
          'Calling his disciples to him, Jesus said, "Truly I tell you, this poor widow has put more into the treasury than all the others."',
    },
    {
      'category': 'Tithe',
      'ref': 'Philippians 4:19',
      'text':
          'And my God will meet all your needs according to the riches of his glory in Christ Jesus.',
    },
    {
      'category': 'Tithe',
      'ref': 'Deuteronomy 15:10',
      'text':
          'Give generously to them and do so without a grudging heart; then because of this the Lord your God will bless you in all your work.',
    },
    {
      'category': 'Tithe',
      'ref': 'James 1:17',
      'text':
          'Every good and perfect gift is from above, coming down from the Father of the heavenly lights.',
    },
    {
      'category': 'Tithe',
      'ref': 'Proverbs 19:17',
      'text':
          'Whoever is kind to the poor lends to the Lord, and he will reward them for what they have done.',
    },

    // =========================================================================
    // CATEGORY: APOSTLES / LEADERSHIP / MINISTRY
    // =========================================================================
    {
      'category': 'Apostles',
      'ref': 'Acts 2:42',
      'text':
          'They devoted themselves to the apostles’ teaching and to fellowship, to the breaking of bread and to prayer.',
    },
    {
      'category': 'Apostles',
      'ref': 'Ephesians 4:11-12',
      'text':
          'So Christ himself gave the apostles, the prophets, the evangelists, the pastors and teachers, to equip his people for works of service.',
    },
    {
      'category': 'Apostles',
      'ref': 'Matthew 10:2',
      'text':
          'These are the names of the twelve apostles: first, Simon (who is called Peter) and his brother Andrew; James son of Zebedee, and his brother John.',
    },
    {
      'category': 'Apostles',
      'ref': '1 Timothy 3:1',
      'text':
          'Here is a trustworthy saying: Whoever aspires to be an overseer desires a noble task.',
    },
    {
      'category': 'Apostles',
      'ref': 'Hebrews 13:17',
      'text':
          'Have confidence in your leaders and submit to their authority, because they keep watch over you as those who must give an account.',
    },
    {
      'category': 'Apostles',
      'ref': 'Mark 10:43-44',
      'text':
          'Instead, whoever wants to become great among you must be your servant, and whoever wants to be first must be slave of all.',
    },
    {
      'category': 'Apostles',
      'ref': '1 Peter 5:2-3',
      'text':
          'Be shepherds of God’s flock that is under your care, watching over them—not because you must, but because you are willing.',
    },
    {
      'category': 'Apostles',
      'ref': 'Acts 1:8',
      'text':
          'But you will receive power when the Holy Spirit comes on you; and you will be my witnesses in Jerusalem, and in all Judea and Samaria, and to the ends of the earth.',
    },
    {
      'category': 'Apostles',
      'ref': '2 Timothy 2:15',
      'text':
          'Do your best to present yourself to God as one approved, a worker who does not need to be ashamed and who correctly handles the word of truth.',
    },
    {
      'category': 'Apostles',
      'ref': 'Proverbs 29:18',
      'text':
          'Where there is no revelation, people cast off restraint; but blessed is the one who heeds wisdom’s instruction.',
    },
    {
      'category': 'Apostles',
      'ref': 'Luke 22:26',
      'text':
          'But you are not to be like that. Instead, the greatest among you should be like the youngest, and the one who rules like the one who serves.',
    },
    {
      'category': 'Apostles',
      'ref': 'John 13:14-15',
      'text':
          'Now that I, your Lord and Teacher, have washed your feet, you also should wash one another’s feet.',
    },
    {
      'category': 'Apostles',
      'ref': 'Acts 4:33',
      'text':
          'With great power the apostles continued to testify to the resurrection of the Lord Jesus. And God’s grace was so powerfully at work in them all.',
    },
    {
      'category': 'Apostles',
      'ref': '1 Corinthians 12:28',
      'text':
          'And God has placed in the church first of all apostles, second prophets, third teachers, then miracles, then gifts of healing...',
    },
    {
      'category': 'Apostles',
      'ref': 'Romans 12:8',
      'text':
          'If it is to encourage, then give encouragement; if it is giving, then give generously; if it is to lead, do it diligently.',
    },
    {
      'category': 'Apostles',
      'ref': 'Titus 1:7',
      'text':
          'Since an overseer manages God’s household, he must be blameless—not overbearing, not quick-tempered, not given to drunkenness.',
    },
    {
      'category': 'Apostles',
      'ref': 'Proverbs 11:14',
      'text':
          'For lack of guidance a nation falls, but victory is won through many advisers.',
    },
    {
      'category': 'Apostles',
      'ref': 'Galatians 6:9',
      'text':
          'Let us not become weary in doing good, for at the proper time we will reap a harvest if we do not give up.',
    },
    {
      'category': 'Apostles',
      'ref': 'Philippians 2:3',
      'text':
          'Do nothing out of selfish ambition or vain conceit. Rather, in humility value others above yourselves.',
    },
    {
      'category': 'Apostles',
      'ref': 'Acts 20:28',
      'text':
          'Keep watch over yourselves and all the flock of which the Holy Spirit has made you overseers. Be shepherds of the church of God.',
    },

    // =========================================================================
    // CATEGORY: HONESTY / INTEGRITY
    // =========================================================================
    {
      'category': 'Honesty',
      'ref': 'Proverbs 12:22',
      'text':
          'The Lord detests lying lips, but he delights in people who are trustworthy.',
    },
    {
      'category': 'Honesty',
      'ref': 'Hebrews 13:18',
      'text':
          'Pray for us. We are sure that we have a clear conscience and desire to live honorably in every way.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 10:9',
      'text':
          'Whoever walks in integrity walks securely, but whoever takes crooked paths will be found out.',
    },
    {
      'category': 'Honesty',
      'ref': 'Colossians 3:9',
      'text':
          'Do not lie to each other, since you have taken off your old self with its practices.',
    },
    {
      'category': 'Honesty',
      'ref': 'Exodus 20:16',
      'text': 'You shall not give false testimony against your neighbor.',
    },
    {
      'category': 'Honesty',
      'ref': 'Ephesians 4:25',
      'text':
          'Therefore each of you must put off falsehood and speak truthfully to your neighbor, for we are all members of one body.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 11:3',
      'text':
          'The integrity of the upright guides them, but the unfaithful are destroyed by their duplicity.',
    },
    {
      'category': 'Honesty',
      'ref': '2 Corinthians 8:21',
      'text':
          'For we are taking pains to do what is right, not only in the eyes of the Lord but also in the eyes of man.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 28:6',
      'text':
          'Better the poor whose walk is blameless than the rich whose ways are perverse.',
    },
    {
      'category': 'Honesty',
      'ref': 'Luke 16:10',
      'text':
          'Whoever can be trusted with very little can also be trusted with much, and whoever is dishonest with very little will also be dishonest with much.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 19:1',
      'text':
          'Better the poor whose walk is blameless than a fool whose lips are perverse.',
    },
    {
      'category': 'Honesty',
      'ref': 'Psalm 25:21',
      'text':
          'May integrity and uprightness protect me, because my hope, Lord, is in you.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 21:3',
      'text':
          'To do what is right and just is more acceptable to the Lord than sacrifice.',
    },
    {
      'category': 'Honesty',
      'ref': '1 Peter 3:10',
      'text':
          'For, "Whoever would love life and see good days must keep their tongue from evil and their lips from deceitful speech."',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 6:16-19',
      'text':
          'There are six things the Lord hates... a lying tongue, hands that shed innocent blood...',
    },
    {
      'category': 'Honesty',
      'ref': 'Leviticus 19:11',
      'text': 'Do not steal. Do not lie. Do not deceive one another.',
    },
    {
      'category': 'Honesty',
      'ref': 'Proverbs 20:7',
      'text':
          'The righteous lead blameless lives; blessed are their children after them.',
    },
    {
      'category': 'Honesty',
      'ref': 'Philippians 4:8',
      'text':
          'Finally, brothers and sisters, whatever is true... think about such things.',
    },
    {
      'category': 'Honesty',
      'ref': 'James 5:12',
      'text':
          'All you need to say is a simple "Yes" or "No". Otherwise you will be condemned.',
    },
    {
      'category': 'Honesty',
      'ref': 'Psalm 15:2',
      'text':
          'The one whose walk is blameless, who does what is righteous, who speaks the truth from their heart.',
    },

    // =========================================================================
    // CATEGORY: DISCIPLINE / SELF-CONTROL
    // =========================================================================
    {
      'category': 'Discipline',
      'ref': 'Hebrews 12:11',
      'text':
          'No discipline seems pleasant at the time, but painful. Later on, however, it produces a harvest of righteousness and peace for those who have been trained by it.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 12:1',
      'text':
          'Whoever loves discipline loves knowledge, but whoever hates correction is stupid.',
    },
    {
      'category': 'Discipline',
      'ref': '2 Timothy 1:7',
      'text':
          'For the Spirit God gave us does not make us timid, but gives us power, love and self-discipline.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 25:28',
      'text':
          'Like a city whose walls are broken through is a person who lacks self-control.',
    },
    {
      'category': 'Discipline',
      'ref': '1 Corinthians 9:27',
      'text':
          'No, I strike a blow to my body and make it my slave so that after I have preached to others, I myself will not be disqualified for the prize.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 13:24',
      'text':
          'Whoever spares the rod hates their children, but the one who loves them is careful to discipline them.',
    },
    {
      'category': 'Discipline',
      'ref': 'Revelation 3:19',
      'text':
          'Those whom I love I rebuke and discipline. So be earnest and repent.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 10:17',
      'text':
          'Whoever heeds discipline shows the way to life, but whoever ignores correction leads others astray.',
    },
    {
      'category': 'Discipline',
      'ref': 'Titus 1:8',
      'text':
          'Rather, he must be hospitable, one who loves what is good, who is self-controlled, upright, holy and disciplined.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 5:23',
      'text':
          'For lack of discipline they will die, led astray by their own great folly.',
    },
    {
      'category': 'Discipline',
      'ref': 'Psalm 94:12',
      'text':
          'Blessed is the one you discipline, Lord, the one you teach from your law.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 29:15',
      'text':
          'A rod and a reprimand impart wisdom, but a child left undisciplined disgraces its mother.',
    },
    {
      'category': 'Discipline',
      'ref': 'Ephesians 6:4',
      'text':
          'Fathers, do not exasperate your children; instead, bring them up in the training and instruction of the Lord.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 15:32',
      'text':
          'Those who disregard discipline despise themselves, but the one who heeds correction gains understanding.',
    },
    {
      'category': 'Discipline',
      'ref': '1 Corinthians 9:25',
      'text':
          'Everyone who competes in the games goes into strict training. They do it to get a crown that will not last, but we do it to get a crown that will last forever.',
    },
    {
      'category': 'Discipline',
      'ref': 'Job 5:17',
      'text':
          'Blessed is the one whom God corrects; so do not despise the discipline of the Almighty.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 23:12',
      'text':
          'Apply your heart to instruction and your ears to words of knowledge.',
    },
    {
      'category': 'Discipline',
      'ref': '1 Peter 1:13',
      'text':
          'Therefore, with minds that are alert and fully sober, set your hope on the grace to be brought to you when Jesus Christ is revealed at his coming.',
    },
    {
      'category': 'Discipline',
      'ref': 'Galatians 5:23',
      'text':
          'Gentleness and self-control. Against such things there is no law.',
    },
    {
      'category': 'Discipline',
      'ref': 'Proverbs 19:18',
      'text':
          'Discipline your children, for in that there is hope; do not be a willing party to their death.',
    },
  ];
}   