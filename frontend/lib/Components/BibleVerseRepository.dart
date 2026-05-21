import 'dart:math';

class GreetingsQuoteRepository {
  static Map<String, String> getDailyQuote({DateTime? date}) {
    final targetDate = date ?? DateTime.now();

    // Create a unique integer based on the Year, Month, and Day.
    final String dateString =
        '${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';
    final int seed = int.parse(dateString);
    final Random random = Random(seed);

    // Pick a random index based on that day's unique seed
    final int index = random.nextInt(_quotes.length);
    return _quotes[index];
  }

  // The Database of quotes extracted from all Apostles in the Greetings
  static final List<Map<String, String>> _quotes = [
    // =========================================================================
    // APOSTLE S.D. PhAKATHI (1990s)
    // =========================================================================
    {
      'category': 'Obedience',
      'ref': 'Apostle S.D. Phakathi (1990s)',
      'text':
          'We must never forget the teachings given to us by our father the Apostle.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle S.D. Phakathi (1990s)',
      'text':
          'Whoever is a true member of the body of Christ should feel the pain when one member is separated from another by different spirits.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle S.D. Phakathi (1990s)',
      'text':
          'Let us remember that the Apostle said we should stay where we are led, walk together, and not clash.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle S.D. Phakathi (1990s)',
      'text':
          'If we love our Apostle, who is a father to us all, let us not accept decisions that divide us.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle S.D. Phakathi (1990s)',
      'text':
          'We must stand together and hold on to the Creator even through pain and difficulties.',
    },

    // =========================================================================
    // APOSTLE J.S. NDLOVU (1975 - 1977)
    // =========================================================================
    {
      'category': 'Obedience',
      'ref': 'Apostle J.S. Ndlovu (1977)',
      'text':
          'The one who acts on their own is harmed by what they do to themselves, but the one who does as instructed is well up to this day.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle J.S. Ndlovu (1977)',
      'text':
          'We moved forward all together, united, with no one acting on their own and disobeying.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle J.S. Ndlovu (1977)',
      'text':
          'It is my wish that you grow with the church with no one doing things differently from others, because by doing so you will be destroying.',
    },
    {
      'category': 'Faith',
      'ref': 'Apostle J.S. Ndlovu (1975/76)',
      'text':
          'Thanking and praising God is not just going to church and breaking bread as a routine, but it is connected with the conscience within a person.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle J.S. Ndlovu (1975/76)',
      'text': 'Break bread even when you are alone wherever you are.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle J.S. Ndlovu (1975/76)',
      'text':
          'Break bread especially when you are doing nothing, so that the evil one does not find you idle and assign you his work.',
    },

    // =========================================================================
    // APOSTLE N.V. MLANGENI (1995 - 2016)
    // =========================================================================
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2015/16)',
      'text':
          'Love others as you love yourself, by so doing you will be loving the one who created you.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2015/16)',
      'text':
          'To look down upon your brother or sister means that you still do not know your creator.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2015/16)',
      'text':
          'He gave you the head and put a brain inside it; you must think and do not be lazy.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2015/16)',
      'text':
          'Learn to ask for something good to be rewarded with that which is good.',
    },
    {
      'category': 'Forgiveness',
      'ref': 'Apostle N.V. Mlangeni (2015/16)',
      'text': 'You must learn to forgive so that you also can be forgiven.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle N.V. Mlangeni (2014)',
      'text':
          'All godly things will happen only if we respect one another and work in unity.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2014)',
      'text':
          'Love one another with godly love, not pretending. God does not want someone who pretends.',
    },
    {
      'category': 'Respect',
      'ref': 'Apostle N.V. Mlangeni (2014)',
      'text': 'Let the young respect the old and the old respect the young.',
    },
    {
      'category': 'Obedience',
      'ref': 'Apostle N.V. Mlangeni (2014)',
      'text':
          'There is nothing better than when each one remains where they are placed.',
    },
    {
      'category': 'Faith',
      'ref': 'Apostle N.V. Mlangeni (2013/14)',
      'text':
          'God gave you strength, and you will build other houses. Stay in one hope.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle N.V. Mlangeni (2013/14)',
      'text':
          'Even when strong winds shake you, stand firm and say, "We are not moving here."',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2013/14)',
      'text': 'Tricks and cleverness come to an end, but foolishness does not.',
    },
    {
      'category': 'Humility',
      'ref': 'Apostle N.V. Mlangeni (2012/13)',
      'text':
          'We must humble ourselves, respect one another, and be like children.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2011/12)',
      'text':
          'Fathers love your wives, mothers love your husbands, so children may learn love at home.',
    },
    {
      'category': 'Faith',
      'ref': 'Apostle N.V. Mlangeni (2011/12)',
      'text':
          'Do not have many hopes, but have one single hope. Do not doubt Him!',
    },
    {
      'category': 'Truth',
      'ref': 'Apostle N.V. Mlangeni (2011/12)',
      'text':
          'If we claim fellowship with Him yet walk in darkness, we lie and do not live by the truth.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2010/11)',
      'text':
          'If we want to see the love God has for us, we must first love one another.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle N.V. Mlangeni (2010/11)',
      'text': 'Dwell in peace, break bread, love one another, and be united.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2009/10)',
      'text': 'It is a mistake to only remember God when we are in difficulty.',
    },
    {
      'category': 'Humility',
      'ref': 'Apostle N.V. Mlangeni (2009/10)',
      'text':
          'I urge you to humble yourselves and be nothing so that God can be something within us.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2008/09)',
      'text': 'Let us love one another because love comes from God.',
    },
    {
      'category': 'Love',
      'ref': 'Apostle N.V. Mlangeni (2008/09)',
      'text': 'Whoever does not love does not know God.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2007/08)',
      'text':
          'If you have an envious eye, it is better to close it to avoid sin.',
    },
    {
      'category': 'Humility',
      'ref': 'Apostle N.V. Mlangeni (2005/06)',
      'text':
          'Whoever wants to be great must first humble themselves to be raised.',
    },
    {
      'category': 'Peace',
      'ref': 'Apostle N.V. Mlangeni (2005/06)',
      'text':
          'Conflict does not come from God, but from the desires of the flesh.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2004/05)',
      'text': 'The nation will change only if we walk in truth and honesty.',
    },
    {
      'category': 'Renewal',
      'ref': 'Apostle N.V. Mlangeni (2004/05)',
      'text': 'Do not envy the work of others; make your own life beautiful.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle N.V. Mlangeni (2002/03)',
      'text':
          'The evil one does not like good things and always tries to divide us.',
    },
    {
      'category': 'Ministry',
      'ref': 'Apostle N.V. Mlangeni (2002/03)',
      'text':
          'An evangelist fetches souls with love, a shepherd guides with truth, and a prophet warns of danger.',
    },
    {
      'category': 'Humility',
      'ref': 'Apostle N.V. Mlangeni (2001/02)',
      'text':
          'Unless you change and become like little children, you will not enter the kingdom.',
    },
    {
      'category': 'Obedience',
      'ref': 'Apostle N.V. Mlangeni (2001/02)',
      'text':
          'Do not despise the word that comes from above, lest you decrease your blessings.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (2000)',
      'text':
          'When a person thinks they are smarter than others, that is exactly where their foolishness begins.',
    },
    {
      'category': 'Unity',
      'ref': 'Apostle N.V. Mlangeni (2000)',
      'text':
          'God bound us with His love to make a golden chain of protection.',
    },
    {
      'category': 'Respect',
      'ref': 'Apostle N.V. Mlangeni (1999)',
      'text':
          'Respect is your key to open, and love is your weapon to conquer.',
    },
    {
      'category': 'Wisdom',
      'ref': 'Apostle N.V. Mlangeni (1999)',
      'text':
          'Let us be careful with our utterances, as our mouths can cause disaster.',
    },
    {
      'category': 'Duty',
      'ref': 'Apostle N.V. Mlangeni (1999)',
      'text': 'Offer your tithes materially and spiritually.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle N.V. Mlangeni (1996/97)',
      'text':
          'May God give you the strength to carry your cross until victory.',
    },
    {
      'category': 'Perseverance',
      'ref': 'Apostle N.V. Mlangeni (1995/96)',
      'text':
          'Christ conquered death through perseverance and trusting in God the Father.',
    },
  ];
}
