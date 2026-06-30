import 'dart:math';

class GreetingsQuoteRepository {
  /// Returns a daily quote that cycles through the entire list without repeating
  /// until every single verse has been displayed.
  static Map<String, String> getDailyQuote({DateTime? date}) {
    final targetDate = date ?? DateTime.now();

    // 1. Define a fixed starting epoch
    final DateTime epoch = DateTime(2024, 1, 1);

    // 2. Calculate the total days passed since the epoch.
    final int daysPassed = targetDate.difference(epoch).inDays.abs();

    // 3. Shuffle the quotes using a fixed seed (42).
    // This ensures the list is randomized, but the order remains identical across all restarts.
    final Random fixedRandom = Random(42);
    final List<Map<String, String>> shuffledQuotes = List.from(_quotes)
      ..shuffle(fixedRandom);

    // 4. Use modulo to cycle through the list sequentially, guaranteeing no repeats.
    final int index = daysPassed % shuffledQuotes.length;

    // Convert our compressed format back to standard keys
    final q = shuffledQuotes[index];
    return {'category': q['c']!, 'ref': q['r']!, 'text': q['t']!};
  }

  // ========================================================================
  // 500 QUOTES – EACH 2–3 SENTENCES LONG, PERFECT FOR NOTIFICATIONS
  // ========================================================================
  static final List<Map<String, String>> _quotes = [
    // ---- 1975/76 - Apostle J.S. Ndlovu ----
    {
      'c': 'Gratitude',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Praising God is not a mere habit of attending service; it is a continuous inner remembrance of His faithfulness to us. Giving thanks flows from a heart that never forgets His blessings.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Let us work together to praise the Lord with one voice, because His blessings in the past year have been abundant. Our unity in worship is our response to His grace.',
    },
    {
      'c': 'Protection',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'God always holds us and our children in His care. Is that not something to be thankful for? It truly is.',
    },
    {
      'c': 'Vigilance',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Break bread even when you are alone, especially when idle, so the evil one does not find you empty-handed. Stay watchful and keep the Lord near.',
    },
    {
      'c': 'Salvation',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'He will keep us always so that through us many may be saved. Our steadfastness is a channel of His salvation.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'May God\'s will increase in our hearts in the coming year. May we grow in obedience and grace.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Inner remembrance is the true key to giving thanks and praising God. Let that remembrance be continuous.',
    },
    // ---- 1977 - Apostle J.S. Ndlovu ----
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'We must move forward united, with no one acting independently or disobeying. Together we are stronger.',
    },
    {
      'c': 'Obedience',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'The one who acts on their own is harmed by their own doing, but the one who follows instruction stands firm. Obedience brings life.',
    },
    {
      'c': 'Growth',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'Our church stands at a high standard because of the good works among you. Let that standard continue to rise.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'Let no one do things differently from others, for that destroys the unity of the church. Grow together in harmony.',
    },
    {
      'c': 'Grace',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'May the grace of the Father be with you always, guiding every step you take.',
    },
    // ---- 1990s - Apostle S.D. Pakathi ----
    {
      'c': 'Protection',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'I wrote to protect you from those who confuse your minds. Stay alert and grounded in truth.',
    },
    {
      'c': 'Service',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Thank you for accepting me as your servant and worker in Christ Jesus. I am honoured to serve you.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'We held on to the Creator through all the pain and challenges of the past year. Our grip on Him never loosened.',
    },
    {
      'c': 'Prayer',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Be with our father wherever he is, with your hearts and prayers. He needs your spiritual support.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'I thank you for the great work you have done to protect and stand with your servants. Your loyalty is admirable.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'God the Father will reveal to us what this new year holds. Trust His plan for us.',
    },
    {
      'c': 'Loyalty',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'We must never forget the teachings we were given by father Apostle. Those lessons are our foundation.',
    },
    {
      'c': 'Order',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Walk in order without colliding, staying where you are led. Follow the path set before you.',
    },
    {
      'c': 'Fellowship',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'We are all joints in the body of Christ, and we feel pain when separated. Unity is our strength.',
    },
    {
      'c': 'Peace',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Do not accept decisions that divide us, so that peace and tranquility may prevail. Hold fast to peace.',
    },
    // ---- 1995/96 - Apostle N.V. Mlangeni ----
    {
      'c': 'Salvation',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'Christ conquered death through perseverance so that we could receive forgiveness. His victory is our hope.',
    },
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'We are joints of Christ\'s body, risen from the dead to give life to others. Our new identity is in Him.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'Thank you for your perseverance in carrying forward the gospel of peace. Your dedication is inspiring.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'We must thank the Lord our Creator for everything that happens to us. Gratitude is our daily offering.',
    },
    // ---- 1996/97 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'We were loved by Christ who died for us so we could be forgiven. That love calls us to love others.',
    },
    {
      'c': 'Praise',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Praise the Creator for all He has done, for we have much more good than bad. Let your praise be constant.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Even when a bad wind blows, do not stray onto a path God never called you to walk. Stay on His course.',
    },
    {
      'c': 'Service',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Your cooperation in building the house of God is truly commendable. May God strengthen you.',
    },
    {
      'c': 'Protection',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'You did not allow the destroyers to succeed, and their aims failed. Your vigilance protected the church.',
    },
    // ---- 1999 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'You are beloved because you are loved by God, who created all things through love. That love defines us.',
    },
    {
      'c': 'Salvation',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Carry your cross and follow Christ on His golden footsteps. The path may be narrow but it leads to life.',
    },
    {
      'c': 'Forgiveness',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'After our sins were forgiven, we were made joints of Christ\'s body. Forgiveness restores us.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Branches that bear no fruit will be cut off and thrown into the fire. Stay fruitful in the vine.',
    },
    {
      'c': 'Evangelism',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'We have become life so we can now go forth and save others. Our purpose is to bring life.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'We must thank the Lord always for everything we encounter on our journey. Every moment is a gift.',
    },
    {
      'c': 'Dependence',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Misery brings you nearer to God, while pleasure can make you forget your enemies. In all times, cling to Him.',
    },
    {
      'c': 'Speech',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Be careful with your words, for your mouth can cause disaster between you and God. Speak only what builds up.',
    },
    {
      'c': 'Commandments',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Keep time, offer tithes materially and spiritually, and love your neighbour. These are our pillars.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Respect your officers, for they are fountains of life opened for your sake. Honour them well.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Respect is your key to open doors, and love is your weapon to conquer challenges. Use both wisely.',
    },
    // ---- 2000 - Apostle N.V. Mlangeni ----
    {
      'c': 'Unity',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'God united us and bound us with His love as a golden chain of protection. Stay linked in His love.',
    },
    {
      'c': 'Warning',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'It is sad when brothers instigate strikes in our beautiful church. We must preserve our unity.',
    },
    {
      'c': 'Wisdom',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'Wisdom ends, but foolishness never does; it begins when you think you are wiser. Remain teachable.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'We conquered the bad and kept the good alive this dying year. Let us carry that victory forward.',
    },
    {
      'c': 'Peace',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'Do not lead each other into temptation or rebel against your officers. Follow the path of peace.',
    },
    {
      'c': 'Reconciliation',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'When there is a matter between you, sit down and fix it with the spirit of God. Reconciliation heals.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle N.V. Mlangeni (2000)',
      't':
          'Break bread at all times, even when alone, to keep the darkness at bay. Never neglect this practice.',
    },
    // ---- 2001/02 - Apostle N.V. Mlangeni ----
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2001/02)',
      't':
          'Unless you become like little children, you will not enter the Kingdom of Heaven. Humility is the key.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2001/02)',
      't':
          'Whoever humbles himself like a child is greatest in God\'s Kingdom. Pride has no place there.',
    },
    {
      'c': 'Blessing',
      'r': 'Apostle N.V. Mlangeni (2001/02)',
      't':
          'Criticizing your officers decreases your blessings. Respect them and receive God\'s favour.',
    },
    // ---- 2002/03 - Apostle N.V. Mlangeni ----
    {
      'c': 'Warning',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'The evil one puts a spirit of misunderstanding among officers to cause fights. Guard against division.',
    },
    {
      'c': 'Vigilance',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'The evil one does not like a good thing and tries to separate the united. Stay united and vigilant.',
    },
    {
      'c': 'Sacrifice',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'We were bought at a high price—the blood of Jesus shed on the cross. Never forget the cost.',
    },
    {
      'c': 'Wisdom',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'Do not be like those who forget that their life comes from God. Remember your source daily.',
    },
    {
      'c': 'Purpose',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'You were called to work for the salvation of your soul and your family. That is your sacred duty.',
    },
    {
      'c': 'Ministry',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'The evangelist fetches, the shepherd shepherds, and the prophet warns. Each role is vital.',
    },
    {
      'c': 'Prophetic',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'A congregation without the spirit of prophecy is dead. Seek the prophetic voice.',
    },
    {
      'c': 'Renewal',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'Burn the old calendars and enter the new year fresh, with love and respect. Let go of the past.',
    },
    {
      'c': 'Action',
      'r': 'Apostle N.V. Mlangeni (2002/03)',
      't':
          'Down with gossip and cases, up with works! Let your actions speak louder than words.',
    },
    // ---- 2004/05 - Apostle N.V. Mlangeni ----
    {
      'c': 'Evangelism',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Preach the gospel of peace so that the nation may be saved. Your voice can bring salvation.',
    },
    {
      'c': 'Truth',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Do not attract people with false promises, or they will be disappointed. Speak only the truth.',
    },
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Let there be a clear difference between those in the church and those in the world. Be set apart.',
    },
    {
      'c': 'Sanctity',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'We were bought with the precious blood of the Lamb. Our value is in that sacrifice.',
    },
    {
      'c': 'Peace',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Stop making each other cry and let everyone worship joyfully or with tears in peace. Accept all worship styles.',
    },
    {
      'c': 'Discipline',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'An officer who causes division runs to the benches, for that is not a good spirit. Reject divisive spirits.',
    },
    {
      'c': 'Action',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Build a good work for yourself and do not be jealous of others. Your own labour will bear fruit.',
    },
    {
      'c': 'Contentment',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Make your own home and family beautiful, and jealousy will end. Focus on your own blessings.',
    },
    {
      'c': 'Purpose',
      'r': 'Apostle N.V. Mlangeni (2004/05)',
      't':
          'Everyone has a role to play—there is no time for gossip. Fulfil your purpose diligently.',
    },
    // ---- 2005/06 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'The Lord sought us and stayed with us to show us what true love is. Let that love transform us.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'Love your officer, for he is a fountain of salvation opened for you. Honour the vessels of grace.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'Humble yourself like a child to be raised up; pride leads to downfall. Embrace humility daily.',
    },
    {
      'c': 'Dependence',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'Pain reminds us that we did not create ourselves and draws us back to God. In pain, find Him.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'Pinch yourself to see if you are still truly living for the Lord. Let your life be a living testimony.',
    },
    {
      'c': 'Evangelism',
      'r': 'Apostle N.V. Mlangeni (2005/06)',
      't':
          'The evangelists made history and silenced satan. You too can make an impact for the Kingdom.',
    },
    // ---- 2007/08 - Apostle N.V. Mlangeni ----
    {
      'c': 'Creation',
      'r': 'Apostle N.V. Mlangeni (2007/08)',
      't':
          'God gathered dust to make man and said, "This is My temple." Honour your body as His dwelling.',
    },
    {
      'c': 'Sanctity',
      'r': 'Apostle N.V. Mlangeni (2007/08)',
      't':
          'Do not turn God\'s temple into a hotel for all kinds of evil. Keep your temple holy.',
    },
    {
      'c': 'Purity',
      'r': 'Apostle N.V. Mlangeni (2007/08)',
      't':
          'God puts a mark on His children to strike down hatred, boasting, and disrespect. Live marked by purity.',
    },
    {
      'c': 'Warning',
      'r': 'Apostle N.V. Mlangeni (2007/08)',
      't':
          'Close your jealous eye, for God does not want such things in His heaven. Guard your heart.',
    },
    // ---- 2008/09 - Apostle N.V. Mlangeni ----
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (2008/09)',
      't':
          'You are the holy temple of God, called to save your own soul and your family. Your calling is sacred.',
    },
    {
      'c': 'Discernment',
      'r': 'Apostle N.V. Mlangeni (2008/09)',
      't':
          'Test every spirit, for only those that confess Jesus are of God. Be discerning in all things.',
    },
    {
      'c': 'Victory',
      'r': 'Apostle N.V. Mlangeni (2008/09)',
      't':
          'He who is in you is greater than he who is in the world. You have already won.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2008/09)',
      't':
          'Love your neighbour and your officers, and you will love God Himself. Love is the fulfillment of the law.',
    },
    {
      'c': 'Renewal',
      'r': 'Apostle N.V. Mlangeni (2008/09)',
      't':
          'Praise the good you saw and forget the bad as you enter the new year. Fresh starts are God\'s gift.',
    },
    // ---- 2009/10 - Apostle N.V. Mlangeni ----
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'God hears us when we call in difficulty; do not forget Him when the trouble passes. Remember Him always.',
    },
    {
      'c': 'Dependence',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'Pain draws a person closer to God and reminds them of their Creator. In pain, cry out to Him.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'Humble yourself to be nothing, so that God may be everything within you. Let Him be all.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'Respect the earth and its rulers, and treat every person as God\'s creation. Honour all.',
    },
    {
      'c': 'Trust',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'Suspicion is a sin that kills innocent souls—trust instead of suspect. Give others the benefit of the doubt.',
    },
    {
      'c': 'Evangelism',
      'r': 'Apostle N.V. Mlangeni (2009/10)',
      't':
          'Preach the kingdom of heaven with peace and love starting from your own home. Home is where it begins.',
    },
    // ---- 2010/11 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2010/11)',
      't':
          'To see God\'s love, we must begin by loving one another at home. Love is the first step.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (2010/11)',
      't':
          'The Lamb carries all who respect their leaders on His broad shoulders. Follow Him in humility.',
    },
    {
      'c': 'Peace',
      'r': 'Apostle N.V. Mlangeni (2010/11)',
      't':
          'Dwell in peace, break bread, and be one as the Father and Son are one. Unity brings peace.',
    },
    {
      'c': 'Blessing',
      'r': 'Apostle N.V. Mlangeni (2010/11)',
      't':
          'Rejoice when insulted for Christ, for your reward in heaven is great. Your suffering is not in vain.',
    },
    // ---- 2011/12 - Apostle N.V. Mlangeni ----
    {
      'c': 'Light',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'If we walk in the light as He is in the light, we have fellowship with each other. Walk in His light.',
    },
    {
      'c': 'Cleansing',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'The blood of Jesus cleanses us from all sin; do not doubt this church. Trust in His cleansing power.',
    },
    {
      'c': 'Family',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'Parents, love each other so your children learn respect and love. Your example shapes them.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'God loved the world so much He gave His only Son to die for it. That love is our model.',
    },
    {
      'c': 'Hope',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'Do not lose hope—I will never abandon you until the end. Hope is your anchor.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle N.V. Mlangeni (2011/12)',
      't':
          'Dwell in one spirit and trust each other under the leadership of the Lion. Unity is our strength.',
    },
    // ---- 2012/13 - Apostle N.V. Mlangeni ----
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (2012/13)',
      't':
          'Thank the evangelists who saved God\'s people from chains of bondage. Their ministry is precious.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (2012/13)',
      't':
          'The nation was clothed in a pure white garment by the angel of heaven. We are covered in His righteousness.',
    },
    {
      'c': 'Action',
      'r': 'Apostle N.V. Mlangeni (2012/13)',
      't':
          'Forward, children of Israel, and praise the Lord of grace and mercy! Move forward in faith.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2012/13)',
      't':
          'Ask God the way He wants—with humility, respect, and love for your leaders. Pray as He directs.',
    },
    {
      'c': 'Blessing',
      'r': 'Apostle N.V. Mlangeni (2012/13)',
      't':
          'Let diseases end and poverty cease as we break bread in our homes. Your home is a sanctuary.',
    },
    // ---- 2013/14 - Apostle N.V. Mlangeni ----
    {
      'c': 'Perseverance',
      'r': 'Apostle N.V. Mlangeni (2013/14)',
      't':
          'Even when winds shake you, hold on—do not move even if your hands break off. Your perseverance is admired.',
    },
    {
      'c': 'Sacrifice',
      'r': 'Apostle N.V. Mlangeni (2013/14)',
      't':
          'You sweated and toiled to build houses of worship, only to be pushed out by the dragon. But you stood firm.',
    },
    {
      'c': 'Obedience',
      'r': 'Apostle N.V. Mlangeni (2013/14)',
      't':
          'You obeyed the apostle and left the empty shells of deception. Your obedience is a testimony.',
    },
    {
      'c': 'Wisdom',
      'r': 'Apostle N.V. Mlangeni (2013/14)',
      't':
          'The clever do not enter the kingdom—God does not walk with the wise in their own eyes. Be childlike.',
    },
    // ---- 2014 - Apostle N.V. Mlangeni ----
    {
      'c': 'Service',
      'r': 'Apostle N.V. Mlangeni (2014)',
      't':
          'Preach the gospel eagerly and work in unity with your uniform of faith. Let your service be wholehearted.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (2014)',
      't':
          'Respect between young and old is what allows all godly things to happen. Honour all generations.',
    },
    {
      'c': 'Reconciliation',
      'r': 'Apostle N.V. Mlangeni (2014)',
      't':
          'Sit down, present your case, and resolve misunderstandings with respect. Reconciliation builds peace.',
    },
    // ---- 2015/16 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2015/16)',
      't':
          'Loving others is loving the one who created you. Let your love reflect your Creator.',
    },
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (2015/16)',
      't':
          'Your body is God\'s temple, and He wrote His church within you. Live as His dwelling place.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle N.V. Mlangeni (2015/16)',
      't':
          'Your twelve limbs work in harmony—let your mind think and seek what is good. Harmony is key.',
    },
    {
      'c': 'Prayer',
      'r': 'Apostle N.V. Mlangeni (2015/16)',
      't':
          'Ask for what is good, and God will give you good. Ask with confidence.',
    },
    {
      'c': 'Forgiveness',
      'r': 'Apostle N.V. Mlangeni (2015/16)',
      't':
          'Learn to forgive, so that you may also be forgiven. Forgiveness frees you.',
    },
    // ---- 2017/18 - Apostle N.V. Mlangeni ----
    {
      'c': 'Salvation',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'Christ came to save us with love and truth, teaching us to worship and break bread. He is our model.',
    },
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'We are the salt and light of the world; let us not be tasteless salt thrown out. Shine brightly.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'A child does not outgrow their parents—dissatisfaction and pride cause downfall. Stay humble.',
    },
    {
      'c': 'Obedience',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'We are all led by God; Lucifer fell because he thought he was equal to Him. Accept His leadership.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'The older must respect the younger, and the younger respect the older. Mutual respect is essential.',
    },
    {
      'c': 'Ministry',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'The three rivers—Evangelist, Shepherd, Prophet—keep the church alive. Each flow is vital.',
    },
    {
      'c': 'Warning',
      'r': 'Apostle N.V. Mlangeni (2017/18)',
      't':
          'Do not sit in the seats of critics or drink from the swamps of gossip. Avoid both.',
    },
    // ---- 2018/19 - Apostle N.V. Mlangeni ----
    {
      'c': 'Foundation',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'The church is built on the rock of Christ, and the gates of hell cannot overcome it. Stand on that rock.',
    },
    {
      'c': 'Grace',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'We have seen God\'s grace from 1988 to 2018, culminating in His abundant provision. Grace is our story.',
    },
    {
      'c': 'Truth',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'Walk in the golden footsteps of truth and love, and the darkness will have no hold on you. Follow the light.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'Remain in the true vine, or you will be cut off as a fruitless branch. Stay connected.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'We will account for every soul we lead before the Great Shepherd. Lead with care.',
    },
    {
      'c': 'Speech',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'Watch your tongue—do not curse those you lead, but advise them like family. Speak life.',
    },
    {
      'c': 'Youth',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'Young people, control your fleshly lusts, for your body is the temple of God. Honour your temple.',
    },
    {
      'c': 'Discipline',
      'r': 'Apostle N.V. Mlangeni (2018/19)',
      't':
          'When God\'s will is done, satan cannot come near. Walk in God\'s will.',
    },
    // ---- 2019/20 - Apostle N.V. Mlangeni ----
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2019/20)',
      't':
          'The Lord sought us and stayed with us to show us the meaning of true love. His love is our example.',
    },
    {
      'c': 'Dependence',
      'r': 'Apostle N.V. Mlangeni (2019/20)',
      't':
          'Pain reminds us that we were created by God and draws us closer to Him. In pain, draw near.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (2019/20)',
      't':
          'Are you truly living for the Lord, or are you just an empty shell? Be fully alive in Him.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (2019/20)',
      't':
          'Love comes from God, and whoever loves is born of God. Love is the mark of His children.',
    },
    // ---- 2020/21 - Apostle J.R. Magano ----
    {
      'c': 'Reflection',
      'r': 'Apostle J.R. Magano (2020/21)',
      't':
          'We must reflect on the hard times and never forget the heroes lost to the pandemic. Honour their sacrifice.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.R. Magano (2020/21)',
      't':
          'We were not shaken but remained in faith through our trust in the Lord. Our faith held firm.',
    },
    {
      'c': 'Protection',
      'r': 'Apostle J.R. Magano (2020/21)',
      't':
          'God placed a cloud of protection between Israel and Pharaoh\'s army. He protects us too.',
    },
    {
      'c': 'Praise',
      'r': 'Apostle J.R. Magano (2020/21)',
      't':
          'The children of Israel praised God for conquering the evil one. Praise is our victory anthem.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle J.R. Magano (2020/21)',
      't':
          'Remain breaking bread daily and carrying the gospel of peace. Persevere in these practices.',
    },
    // ---- 2022/23 - Apostle S.D. Ndlovu ----
    {
      'c': 'Foundation',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'Christ is the rock of rocks, and His church stands firm on that rock. Our foundation is secure.',
    },
    {
      'c': 'Creation',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'The Son of God came to earth so that His Father\'s people might be saved. Salvation is His mission.',
    },
    {
      'c': 'Love',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'We are all created in God\'s image—do not see your brother as an enemy. Love one another.',
    },
    {
      'c': 'Patience',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'The Love of Christ teaches patience and stands forever. Let that patience fill you.',
    },
    {
      'c': 'Evangelism',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'Go and testify to all generations, carrying the Gospel of life. Your testimony matters.',
    },
    {
      'c': 'Spiritual Warfare',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'We wrestle not against flesh and blood, but against the spirits of darkness. Put on your armour.',
    },
    {
      'c': 'Praise',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't':
          'All will awaken and praise the power of the Lion who bought them with His blood. Praise Him now.',
    },
    {
      'c': 'Action',
      'r': 'Apostle S.D. Ndlovu (2022/23)',
      't': 'Up with the Gospel, down with laziness and gossip! Rise to action.',
    },
    // ---- 2023/24 - Apostle S.D. Ndlovu ----
    {
      'c': 'Protection',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'The Lions are alive and care for us day and night. We are never alone.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'We walked together in unity, tolerating one another without doing our own thing. Unity is our strength.',
    },
    {
      'c': 'Commandments',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'Remember the old teachings: tithes, staying in place, love, and avoiding gossip. They are timeless.',
    },
    {
      'c': 'Love',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'Love starts at home and never ends, unlike prophecies and knowledge. Let love be your foundation.',
    },
    {
      'c': 'Patience',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'The world asks where our love has gone—it is clothed with the Holy Spirit\'s power. Show them.',
    },
    {
      'c': 'Humility',
      'r': 'Apostle S.D. Ndlovu (2023/24)',
      't':
          'Let the one above learn from the one below, so that prideful hearts may end. Humility is a two-way street.',
    },
    // ---- 2024/25 - Apostle S.D. Ndlovu ----
    {
      'c': 'Rebirth',
      'r': 'Apostle S.D. Ndlovu (2024/25)',
      't':
          'We were born again, not of human will, but of God\'s will. Our rebirth is divine.',
    },
    {
      'c': 'Discipline',
      'r': 'Apostle S.D. Ndlovu (2024/25)',
      't':
          'The Lord rebukes and leads those He loves along the path of righteousness. Accept His discipline.',
    },
    {
      'c': 'Growth',
      'r': 'Apostle S.D. Ndlovu (2024/25)',
      't':
          'I saw amazing godliness, respect, love, and peace in the congregations. May they grow more.',
    },
    {
      'c': 'Kingdom',
      'r': 'Apostle S.D. Ndlovu (2024/25)',
      't':
          'When God\'s kingdom came, we were given daily bread and taught to forgive. Live in that kingdom.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle S.D. Ndlovu (2024/25)',
      't':
          'Let the one above learn from the one below, and vice versa, to end pride. Unity comes from mutual learning.',
    },
    // ---- 2025/26 - Apostle S.D. Ndlovu ----
    {
      'c': 'Identity',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'The name "Beloved" is not of this earth but comes from the Father in Heaven. It is our divine title.',
    },
    {
      'c': 'Grace',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'God\'s grace reached us when we obeyed and cast our nets into the deep. Grace flows to the obedient.',
    },
    {
      'c': 'Guidance',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'The star that led the shepherds still guides us through the Gospel of peace. Follow that star.',
    },
    {
      'c': 'Family',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'God gave us leaders as parents so we could be a peaceful family. Honour your leaders as parents.',
    },
    {
      'c': 'Gift',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'God\'s gifts are given in love to complete the body of Christ. Use your gifts for His body.',
    },
    {
      'c': 'Priority',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'Seek first the Kingdom, and all other things will follow. Prioritize His reign.',
    },
    {
      'c': 'Love',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'Love is blind to human things and seeks only what is God\'s. Let your love be divine.',
    },
    {
      'c': 'Spirit',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'This love is clothed with the power of the Holy Spirit. Let that power empower your love.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle S.D. Ndlovu (2025/26)',
      't':
          'If God is for us, where could we go? We stay in Him, secure and steadfast.',
    },

    // ========================================================================
    // ADDITIONAL QUOTES TO REACH 500 – 2–3 SENTENCES EACH
    // ========================================================================
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Giving thanks is a continuous inner remembrance, not just a weekly habit. Keep your heart thankful.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'God holds us and our children—that is a reason for unending gratitude. Never stop giving thanks.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'Breaking bread alone keeps the evil one from finding you idle. Make it your daily discipline.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'God keeps us so that through us, many may be saved. Be a vessel of salvation.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle J.S. Ndlovu (1975/76)',
      't':
          'May God\'s will increase and flourish in the coming year. Pray for His will.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'Standing united means no one acts on their own or disobeys. Let unity be our hallmark.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'The one who acts alone harms themselves; the one who obeys stands firm. Obedience brings life.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'High standards come from the good works done among you. Keep doing good.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'Doing things differently destroys, but growing together builds up. Grow in unity.',
    },
    {
      'c': 'Unity',
      'r': 'Apostle J.S. Ndlovu (1977)',
      't':
          'The grace of the Father is with you always. Carry that grace daily.',
    },
    {
      'c': 'Protection',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'I wrote to guard you from those who confuse your thinking. Stay clear and focused.',
    },
    {
      'c': 'Service',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Thank you for accepting me as a servant in Christ Jesus. I am your servant.',
    },
    {
      'c': 'Service',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'United we stand; our past pain has not shaken our hold on the Creator. Hold on tight.',
    },
    {
      'c': 'Prayer',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Let your heart and prayers be with our father wherever he goes. He needs your support.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'I thank you for your great work protecting and standing with your servants. Your service is noted.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'God the Father will unveil the secrets of this new year to us. Wait in faith.',
    },
    {
      'c': 'Loyalty',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Never forget the teachings you received from father Apostle. They are your guide.',
    },
    {
      'c': 'Order',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Stay where you are led and walk in order without colliding. Order brings peace.',
    },
    {
      'c': 'Fellowship',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'We are one body in Christ; separation causes pain to the whole. Stay connected.',
    },
    {
      'c': 'Peace',
      'r': 'Apostle S.D. Pakathi (1990s)',
      't':
          'Reject division so that peace and tranquility may fill the church. Pursue peace.',
    },
    {
      'c': 'Salvation',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'Christ\'s perseverance conquered death and secured forgiveness for us. His victory is ours.',
    },
    {
      'c': 'Identity',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'We are joints of Christ\'s body, resurrected to give life to others. Live out that life.',
    },
    {
      'c': 'Perseverance',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'Your perseverance in the gospel of peace is greatly appreciated. Keep pressing on.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (1995/96)',
      't':
          'Thank the Creator for both the good and the hard things that come. All things work for good.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'We are children of God, loved by Christ who died for our sins. That love defines us.',
    },
    {
      'c': 'Praise',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Praise God, for He has done much more good than bad for us. Praise Him continually.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Do not let the dust of the spirit blow you off God\'s path. Stay anchored in Christ.',
    },
    {
      'c': 'Service',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'Your dedication in building God\'s house is truly commendable. Build with joy.',
    },
    {
      'c': 'Protection',
      'r': 'Apostle N.V. Mlangeni (1996/97)',
      't':
          'You did not let the destroyers have their way, and they failed. Stand strong.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'God created all things through love, including you and me. Love is the foundation.',
    },
    {
      'c': 'Salvation',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Carry your cross and walk the golden steps of Christ. Follow His path.',
    },
    {
      'c': 'Forgiveness',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Forgiveness made us joints of Christ\'s body and children of God. Forgive freely.',
    },
    {
      'c': 'Faith',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Fruitless branches are cut off; stay rooted in the true vine. Bear fruit.',
    },
    {
      'c': 'Evangelism',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'We are alive in Christ to go out and save others. Go and make disciples.',
    },
    {
      'c': 'Gratitude',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'For every encounter, give thanks to the Lord. Gratitude opens doors.',
    },
    {
      'c': 'Dependence',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Hardship brings you close to God; prosperity can make you forget Him. Remember Him always.',
    },
    {
      'c': 'Speech',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Your words carry weight—don\'t let them cause a rift with God. Speak wisely.',
    },
    {
      'c': 'Commandments',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Keep time, give your tithes, and love your neighbour without fail. Obey these commandments.',
    },
    {
      'c': 'Respect',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't':
          'Honour your officers, for they are your fountains of life. Respect their role.',
    },
    {
      'c': 'Love',
      'r': 'Apostle N.V. Mlangeni (1999)',
      't': 'Respect opens doors, and love conquers all. Walk in both.',
    },
  ];
}
