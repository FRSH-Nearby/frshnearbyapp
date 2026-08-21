import 'package:flutter/material.dart' as material;

/// Drop-in localized text for the app's legacy screens.
///
/// New copy should normally be added to the ARB catalog. This adapter keeps the
/// existing widget API while ensuring all current English source copy follows
/// the active Flutter locale.
class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  final String? data;
  final material.InlineSpan? textSpan;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) {
    if (textSpan != null) {
      return material.Text.rich(
        textSpan!,
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
    return material.Text(
      localizeText(context, data ?? ''),
      key: key,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      textScaler: textScaler,
      maxLines: maxLines,
      semanticsLabel:
          semanticsLabel == null
              ? null
              : localizeText(context, semanticsLabel!),
      textWidthBasis: textWidthBasis,
      textHeightBehavior: textHeightBehavior,
      selectionColor: selectionColor,
    );
  }
}

String localizeText(material.BuildContext context, String source) {
  final language = material.Localizations.localeOf(context).languageCode;
  if (language == 'en' || source.trim().isEmpty) return source;
  final catalog =
      language == 'fi'
          ? _fi
          : language == 'sv'
          ? _sv
          : null;
  if (catalog == null) return source;
  final direct = catalog[source];
  if (direct != null) return direct;

  const requiredSuffix = ' is required.';
  if (source.endsWith(requiredSuffix)) {
    final label = source.substring(0, source.length - requiredSuffix.length);
    final translatedLabel = catalog[label] ?? label;
    final translatedSuffix = catalog['requiredSuffix'];
    if (translatedSuffix != null) return '$translatedLabel$translatedSuffix';
  }

  // Preserve runtime values in the few interpolated messages in this flow.
  const patterns = <String, String>{
    'We sent a 6-digit code to\n': 'verificationEmailPrefix',
    'Code expires in ': 'codeExpiresPrefix',
    'Resend in ': 'resendPrefix',
    'Upload ': 'uploadPrefix',
    'Consumer + ': 'consumerPlusPrefix',
    'Hello, ': 'helloPrefix',
  };
  for (final entry in patterns.entries) {
    if (source.startsWith(entry.key)) {
      final translatedPrefix = catalog[entry.value];
      if (translatedPrefix != null) {
        final remainder = source.substring(entry.key.length);
        final translatedRemainder =
            entry.value == 'uploadPrefix' || entry.value == 'consumerPlusPrefix'
                ? (catalog[remainder] ?? remainder)
                : remainder;
        return '$translatedPrefix$translatedRemainder';
      }
    }
  }
  return source;
}

const _fi = <String, String>{
  'verificationEmailPrefix': 'Lähetimme 6-numeroisen koodin osoitteeseen\n',
  'codeExpiresPrefix': 'Koodi vanhenee: ',
  'resendPrefix': 'Lähetä uudelleen: ',
  'uploadPrefix': 'Lataa ',
  'consumerPlusPrefix': 'Kuluttaja + ',
  'helloPrefix': 'Hei, ',
  'requiredSuffix': ' on pakollinen.',
  'Choose from photos': 'Valitse kuvista',
  'Take a photo': 'Ota kuva',
  'A new verification code was sent.': 'Uusi vahvistuskoodi lähetettiin.',
  'Password reset email sent.': 'Salasanan palautusviesti lähetettiin.',
  'Your verification request was sent for review.':
      'Vahvistuspyyntösi lähetettiin tarkistettavaksi.',
  'Sign-in could not be completed. Please try again.':
      'Kirjautumista ei voitu suorittaa. Yritä uudelleen.',
  'Enter the 6-digit verification code.': 'Anna 6-numeroinen vahvistuskoodi.',
  'Your session expired. Please sign in again.':
      'Istuntosi vanheni. Kirjaudu uudelleen.',
  'Confirm your location before continuing.':
      'Vahvista sijaintisi ennen jatkamista.',
  'Enter your email address first.': 'Anna ensin sähköpostiosoitteesi.',
  'Add a written response before submitting.':
      'Lisää kirjallinen vastaus ennen lähettämistä.',
  'Confirm your details before submitting.':
      'Vahvista tietosi ennen lähettämistä.',
  'Each verification file must be 8 MB or smaller.':
      'Jokaisen vahvistustiedoston on oltava enintään 8 Mt.',
  'Upload a PDF, JPG, PNG, or WEBP file.':
      'Lataa PDF-, JPG-, PNG- tai WEBP-tiedosto.',
  'This email already has an account. Try signing in.':
      'Tällä sähköpostilla on jo tili. Kokeile kirjautua sisään.',
  'The email or password is incorrect.':
      'Sähköposti tai salasana on virheellinen.',
  'Choose a stronger password.': 'Valitse vahvempi salasana.',
  'Check your internet connection.': 'Tarkista internetyhteytesi.',
  'This email uses another sign-in method. Use that method first.':
      'Tämä sähköposti käyttää toista kirjautumistapaa. Käytä ensin sitä.',
  'This sign-in method is not enabled in Firebase yet.':
      'Tätä kirjautumistapaa ei ole vielä otettu käyttöön.',
  'Authentication failed. Please try again.':
      'Tunnistautuminen epäonnistui. Yritä uudelleen.',
  'This phone number is already registered. Sign in to the existing account or use another number.':
      'Tämä puhelinnumero on jo rekisteröity. Kirjaudu olemassa olevalle tilille tai käytä toista numeroa.',
  'Confirm your registered location first.':
      'Vahvista ensin rekisteröity sijaintisi.',
  'A few details now, then make FRSH yours.':
      'Vielä muutama tieto, sitten FRSH on sinun.',
  'This is how local customers will recognise you.':
      'Näin paikalliset asiakkaat tunnistavat sinut.',
  'Your local food journey starts now.': 'Paikallinen ruokamatkasi alkaa nyt.',
  'FRSH member': 'FRSH-jäsen',
  'Business profile': 'Yritysprofiili',
  'Seller profile': 'Myyjäprofiili',
  'Resubmit for verification': 'Lähetä uudelleen vahvistettavaksi',
  'Where is your business?': 'Missä yrityksesi sijaitsee?',
  'Add the storefront, farm or operating location customers should discover.':
      'Lisää myymälä, maatila tai toimipaikka, jonka asiakkaiden tulisi löytää.',
  'Finding this address…': 'Etsitään osoitetta…',
  'Select your date of birth.': 'Valitse syntymäaikasi.',
  'Select a business type.': 'Valitse yritystyyppi.',
  'Enter a valid phone number.': 'Anna kelvollinen puhelinnumero.',
  'Required': 'Pakollinen',
  'DRAFT': 'LUONNOS',
  'NEEDS CHANGES': 'MUUTOKSIA TARVITAAN',
  'REJECTED': 'HYLÄTTY',
  'VERIFIED': 'VAHVISTETTU',
  'PENDING': 'ODOTTAA',
  'Discover': 'Löydä',
  'Market': 'Tori',
  'Profile': 'Profiili',
  'Discover is coming next': 'Löydä-näkymä valmistuu seuraavaksi',
  'Marketplace is coming next': 'Tori valmistuu seuraavaksi',
  'Action required for verification': 'Vahvistus vaatii toimenpiteitä',
  'Verification under review': 'Vahvistus tarkistettavana',
  'Verification pending': 'Vahvistus odottaa tarkistusta',
  'Verification needs your attention': 'Vahvistus vaatii huomiotasi',
  'Verify your seller profile': 'Vahvista myyjäprofiilisi',
  'The verification team needs more information.':
      'Vahvistustiimi tarvitsee lisätietoja.',
  'We will notify you when the review is complete.':
      'Ilmoitamme, kun tarkistus on valmis.',
  'Review the decision and submit a new request.':
      'Tarkista päätös ja lähetä uusi pyyntö.',
  'Complete verification to unlock seller features.':
      'Vahvista profiilisi käyttääksesi myyjätoimintoja.',
  'Verified seller': 'Vahvistettu myyjä',
  'Help customers trust your seller profile by confirming who you are.':
      'Vahvista henkilöllisyytesi, jotta asiakkaat voivat luottaa myyjäprofiiliisi.',
  'Your documents were submitted. We will notify you when the review is complete.':
      'Asiakirjasi on lähetetty. Ilmoitamme, kun tarkistus on valmis.',
  'No action is needed while the verification team reviews your submission.':
      'Sinun ei tarvitse tehdä mitään vahvistustiimin tarkistaessa lähetystäsi.',
  'Submit requested information': 'Lähetä pyydetyt tiedot',
  'Submit for verification': 'Lähetä vahvistettavaksi',
  'Settings': 'Asetukset',
  'Language': 'Kieli',
  'Choose the language used throughout the app.':
      'Valitse koko sovelluksessa käytettävä kieli.',
  'English': 'Englanti',
  'Finnish': 'Suomi',
  'Swedish': 'Ruotsi',
  'Active account': 'Aktiivinen tili',
  'Switch how you are using FRSH. This does not remove either profile.':
      'Vaihda FRSH:n käyttötapaa. Tämä ei poista kumpaakaan profiilia.',
  'Consumer account': 'Kuluttajatili',
  'Business account': 'Yritystili',
  'Side-hustler account': 'Sivutoimisen tuottajan tili',
  'Discover and buy local food': 'Löydä ja osta paikallista ruokaa',
  'Manage your registered business profile':
      'Hallinnoi rekisteröityä yritysprofiiliasi',
  'Manage your producer profile': 'Hallinnoi tuottajaprofiiliasi',
  'YOUR SETUP': 'ASETUKSESI',
  'WELCOME': 'TERVETULOA',
  'Fresh food near you': 'Tuoretta ruokaa läheltäsi',
  'One account for discovering, making and selling local food.':
      'Yksi tili paikallisen ruoan löytämiseen, valmistamiseen ja myymiseen.',
  'Continue with Google': 'Jatka Googlella',
  'or': 'tai',
  'Continue with email': 'Jatka sähköpostilla',
  'Secure sign-in • your saved setup resumes automatically':
      'Turvallinen kirjautuminen • tallennettua määritystä jatketaan automaattisesti',
  'YOUR ACCOUNT': 'TILISI',
  'Create your account': 'Luo tilisi',
  'Welcome back': 'Tervetuloa takaisin',
  'Use the email and password you registered with.':
      'Käytä rekisteröimääsi sähköpostia ja salasanaa.',
  'Create account': 'Luo tili',
  'Sign in': 'Kirjaudu sisään',
  'Email address': 'Sähköpostiosoite',
  'Enter a valid email address.': 'Anna kelvollinen sähköpostiosoite.',
  'Password': 'Salasana',
  'Use at least 8 characters.': 'Käytä vähintään 8 merkkiä.',
  'Confirm password': 'Vahvista salasana',
  'Passwords do not match.': 'Salasanat eivät täsmää.',
  'Forgot password?': 'Unohditko salasanan?',
  'Continue': 'Jatka',
  'STEP 1 OF 4': 'VAIHE 1/4',
  'How will you use FRSH?': 'Miten käytät FRSH:ta?',
  'You can also be a consumer. Choose only one type of seller profile.':
      'Voit olla myös kuluttaja. Valitse vain yksi myyjäprofiilin tyyppi.',
  'Consumer': 'Kuluttaja',
  'Discover fresh food and trusted makers nearby.':
      'Löydä tuoretta ruokaa ja luotettavia tuottajia läheltä.',
  'Side-hustle producer': 'Sivutoiminen tuottaja',
  'Sell small-batch, seasonal or homemade products.':
      'Myy pieneriä, kausituotteita tai kotitekoisia tuotteita.',
  'INDIVIDUAL': 'YKSITYINEN',
  'Registered business': 'Rekisteröity yritys',
  'Build a verified storefront for your farm or company.':
      'Luo vahvistettu myymälä maatilallesi tai yrityksellesi.',
  'BUSINESS': 'YRITYS',
  'Enter verification code': 'Anna vahvistuskoodi',
  'Check your inbox and spam folder. The code is sent by FRSH Nearby and expires soon.':
      'Tarkista saapuneet viestit ja roskaposti. FRSH Nearby lähettää koodin, joka vanhenee pian.',
  'Verification code': 'Vahvistuskoodi',
  'Verify email': 'Vahvista sähköposti',
  'Use a different email': 'Käytä toista sähköpostia',
  'STEP 2 OF 4': 'VAIHE 2/4',
  'Create your public profile': 'Luo julkinen profiilisi',
  'Tell us about you': 'Kerro itsestäsi',
  'We use this to make your experience feel local.':
      'Käytämme tätä tehdäksemme kokemuksestasi paikallisen.',
  'Full name': 'Koko nimi',
  'Verified email address': 'Vahvistettu sähköpostiosoite',
  'Date of birth *': 'Syntymäaika *',
  'Select date': 'Valitse päivämäärä',
  'Display name (public)': 'Näyttönimi (julkinen)',
  'Short introduction': 'Lyhyt esittely',
  'What do you make or grow?': 'Mitä valmistat tai kasvatat?',
  'STEP 3 OF 4': 'VAIHE 3/4',
  'Business details': 'Yrityksen tiedot',
  'These details help us verify your storefront. Only your public name and address area are shown.':
      'Nämä tiedot auttavat vahvistamaan myymäläsi. Vain julkinen nimesi ja osoitealueesi näytetään.',
  'Business name': 'Yrityksen nimi',
  'Farm name': 'Maatilan nimi',
  'Business ID': 'Y-tunnus',
  'VAT number': 'ALV-numero',
  'Business type *': 'Yritystyyppi *',
  'Farm': 'Maatila',
  'Food producer': 'Elintarviketuottaja',
  'Retailer': 'Jälleenmyyjä',
  'Other': 'Muu',
  'Business address': 'Yrityksen osoite',
  'City': 'Kaupunki',
  'Zip code': 'Postinumero',
  'Review application': 'Tarkista hakemus',
  'FINAL STEP': 'VIIMEINEN VAIHE',
  'Everything looks fresh': 'Kaikki näyttää hyvältä',
  'Confirm what we saved. You can edit anything before continuing.':
      'Vahvista tallennetut tiedot. Voit muokata niitä ennen jatkamista.',
  'Account type': 'Tilityyppi',
  'Public identity': 'Julkinen identiteetti',
  'Registered location': 'Rekisteröity sijainti',
  'Seller verification': 'Myyjän vahvistus',
  'Available later from your profile': 'Saatavilla myöhemmin profiilistasi',
  'Your private account and verification details are never displayed publicly.':
      'Yksityisiä tili- ja vahvistustietojasi ei koskaan näytetä julkisesti.',
  'Create my account': 'Luo tilini',
  'By continuing, you agree to our Terms and Privacy Policy.':
      'Jatkamalla hyväksyt käyttöehdot ja tietosuojakäytännön.',
  'Welcome to FRSH nearby!': 'Tervetuloa FRSH nearbyhin!',
  'Your profile is ready. You can apply for seller verification later from your profile.':
      'Profiilisi on valmis. Voit hakea myyjän vahvistusta myöhemmin profiilistasi.',
  'Explore FRSH': 'Tutustu FRSH:iin',
  'YOUR PROFILE': 'PROFIILISI',
  'Edit profile': 'Muokkaa profiilia',
  'Account details': 'Tilin tiedot',
  'Apply for verification': 'Hae vahvistusta',
  'Sign out': 'Kirjaudu ulos',
  'Edit': 'Muokkaa',
  'Delete': 'Poista',
  'Available': 'Saatavilla',
  'Unavailable': 'Ei saatavilla',
  'Sold out': 'Loppuunmyyty',
  'Visible to customers': 'Näkyy asiakkaille',
  'Hidden from customers': 'Piilotettu asiakkailta',
  'Make available': 'Aseta saataville',
  'Make unavailable': 'Poista saatavilta',
  'Use ⋮ menu': 'Käytä ⋮-valikkoa',
  'Set exact quantity': 'Aseta tarkka määrä',
  'Decimals are allowed for weight and liquid.':
      'Desimaalit ovat sallittuja painolle ja nesteille.',
  'Quantity button step': 'Määräpainikkeen askel',
  'Amount added or removed with each + or − tap.':
      'Määrä, joka lisätään tai poistetaan jokaisella + tai − painalluksella.',
  'Save': 'Tallenna',
  'Try again': 'Yritä uudelleen',
  'Cancel': 'Peruuta',
  'Edit Hot Sale': 'Muokkaa Hot Sale -tuotetta',
  'Save changes': 'Tallenna muutokset',
  'Delete product?': 'Poistetaanko tuote?',
  'This will remove': 'Tämä poistaa tuotteen',
  'from your Hot Sales list.': 'Hot Sales -listaltasi.',
  'No products yet. Add your first seasonal product.':
      'Ei vielä tuotteita. Lisää ensimmäinen kausituotteesi.',
  'Business registration': 'Yritysrekisteriote',
  'Tax or VAT document': 'Vero- tai ALV-asiakirja',
  'Proof of identity': 'Henkilöllisyystodistus',
  'Activity or location proof': 'Todistus toiminnasta tai sijainnista',
  'Business registration proof': 'Todistus yrityksen rekisteröinnistä',
  'Other document': 'Muu asiakirja',
  'Verification document': 'Vahvistusasiakirja',
  'proof of identity': 'henkilöllisyystodistus',
  'business registration proof': 'todistus yrityksen rekisteröinnistä',
  'tax or VAT document': 'vero- tai ALV-asiakirja',
  'activity or location proof': 'todistus toiminnasta tai sijainnista',
  'other document': 'muu asiakirja',
  'verification document': 'vahvistusasiakirja',
  'Requested update': 'Pyydetty päivitys',
  'Verification proof': 'Vahvistustodiste',
  'Review the details above, attach proof, then confirm they are correct.':
      'Tarkista yllä olevat tiedot, liitä todiste ja vahvista tietojen oikeellisuus.',
  'No new file upload requested.': 'Uutta tiedostoa ei pyydetty.',
  'Response to reviewer': 'Vastaus tarkistajalle',
  'Answer the question or explain what you changed.':
      'Vastaa kysymykseen tai selitä tekemäsi muutokset.',
  'I confirm these details are accurate and I am responsible for the products I sell.':
      'Vahvistan tietojen oikeellisuuden ja vastaan myymistäni tuotteista.',
  'PDF or image upload': 'Lataa PDF tai kuva',
  'Add': 'Lisää',
  'Remove': 'Poista',
  'Add profile photo · optional': 'Lisää profiilikuva · valinnainen',
  'Search country or code': 'Hae maata tai koodia',
  'Phone number *': 'Puhelinnumero *',
  'Phone number': 'Puhelinnumero',
  'Business location': 'Yrityksen sijainti',
  'Seller location': 'Myyjän sijainti',
  'Your location': 'Sijaintisi',
  'This location powers nearby discovery.':
      'Tämän sijainnin avulla löydät lähellä olevat kohteet.',
  'Turn on location services, or enter your address manually.':
      'Ota sijaintipalvelut käyttöön tai anna osoite käsin.',
  'Location permission was not granted. Enter your address manually.':
      'Sijaintilupaa ei myönnetty. Anna osoite käsin.',
  'We found your position but not its street address. Enter it manually.':
      'Löysimme sijaintisi, mutta emme katuosoitetta. Anna se käsin.',
  'We could not locate this address. Check it and try again.':
      'Osoitetta ei löytynyt. Tarkista se ja yritä uudelleen.',
  'Where do you make or sell?': 'Missä valmistat tai myyt?',
  'Choose your location': 'Valitse sijaintisi',
  'We use this location to show nearby producers, products and Hot Sales. Use your current location or choose another area.':
      'Näytämme tämän sijainnin perusteella lähellä olevia tuottajia, tuotteita ja Hot Sale -tarjouksia. Käytä nykyistä sijaintiasi tai valitse toinen alue.',
  'Add your farm, kitchen, pickup point or production location.':
      'Lisää maatila, keittiö, noutopiste tai tuotantopaikka.',
  'Suggest from my current position': 'Ehdota nykyisen sijaintini perusteella',
  'Optional shortcut only. Edit the address below if you are not currently at the seller location.':
      'Valinnainen oikotie. Muokkaa alla olevaa osoitetta, jos et ole nyt myyjän sijainnissa.',
  'Use your current location or choose another location below.':
      'Käytä nykyistä sijaintiasi tai valitse alta toinen sijainti.',
  'Zoom in and tap your preferred location. The marker and address fields will update.':
      'Lähennä karttaa ja napauta haluamaasi sijaintia. Merkki ja osoitekentät päivittyvät.',
  'Street address and number *': 'Katuosoite ja numero *',
  'For example: Market Street 12': 'Esimerkiksi: Kauppakatu 12',
  'Building, block, unit or floor': 'Rakennus, rappu, asunto tai kerros',
  'For example: Building B, unit 4': 'Esimerkiksi: rakennus B, asunto 4',
  'Address lookup © OpenStreetMap contributors. Please confirm the street before saving.':
      'Osoitehaku © OpenStreetMapin tekijät. Vahvista katu ennen tallentamista.',
  'Postal code *': 'Postinumero *',
  'City *': 'Kaupunki *',
  'Country *': 'Maa *',
  'Confirm seller location': 'Vahvista myyjän sijainti',
  'Confirm location': 'Vahvista sijainti',
  'Discover local producers': 'Löydä paikalliset tuottajat',
  'Seasonal food and small businesses, close to home.':
      'Sesonkiruokaa ja pienyrityksiä läheltä kotia.',
  'Browse by category': 'Selaa kategorioittain',
  'Vegetables': 'Vihannekset',
  'Bakery': 'Leipomo',
  'Eggs & dairy': 'Munat ja maitotuotteet',
  'Nearby sellers': 'Lähialueen myyjät',
  'Local sellers and their products will appear here as the marketplace opens.':
      'Paikalliset myyjät ja tuotteet tulevat näkyviin, kun markkinapaikka avautuu.',
  'SELLER WORKSPACE': 'MYYJÄN TYÖTILA',
  'Your business': 'Yrityksesi',
  'Active orders': 'Aktiiviset tilaukset',
  'This month': 'Tässä kuussa',
  'Quick actions': 'Pikatoiminnot',
  'Start selling locally': 'Aloita paikallinen myynti',
  'Products, inventory, and incoming orders will live in this seller workspace.':
      'Tuotteet, varasto ja saapuvat tilaukset löytyvät tästä myyjän työtilasta.',
  'My profile': 'Oma profiili',
  'Personal details': 'Henkilötiedot',
  'Your local marketplace is coming next':
      'Paikallinen markkinapaikka on tulossa seuraavaksi',
  'Seller orders are coming next': 'Myyjän tilaukset ovat tulossa seuraavaksi',
  'Home': 'Koti',
  'Dashboard': 'Hallintapaneeli',
  'Orders': 'Tilaukset',
  'Explore': 'Tutki',
  'Current location': 'Nykyinen sijainti',
  'Use current location': 'Käytä nykyistä sijaintia',
  'Hide farm tile': 'Piilota tilakortti',
  'Show farm tile': 'Näytä tilakortti',
  'Could not load nearby Hot Sales': 'Lähialueen pikamyyntejä ei voitu ladata',
  'Hot Sales nearby': 'pikamyyntiä lähellä',
  'km away': 'km päässä',
  'available': 'saatavilla',
  'product in basket': 'tuote ostoskorissa',
  'products in basket': 'tuotetta ostoskorissa',
  'Request order': 'Lähetä tilauspyyntö',
  'Sending request…': 'Lähetetään pyyntöä…',
  'Subtotal': 'Välisumma',
  'kilogram': 'kilogramma',
  'gram': 'gramma',
  'other': 'muu',
  'Your basket': 'Ostoskorisi',
  'Pickup place': 'Noutopaikka',
  'Farm pickup': 'Nouto tilalta',
  'Select a pickup place.': 'Valitse noutopaikka.',
  'Total': 'Yhteensä',
  'Order request sent to the farm.': 'Tilauspyyntö lähetettiin tilalle.',
  'Sold by': 'Myyjä',
  'Available at': 'Saatavilla kohteessa',
  'Translated from': 'Käännetty kielestä',
  'Original': 'Alkuperäinen',
  'No farm Hot Sales within 50 km yet':
      'Ei tilojen pikamyyntejä 50 km:n säteellä',
  'New seasonal products will appear here.':
      'Uudet kausituotteet näkyvät täällä.',
  'Farm orders': 'Tilan tilaukset',
  'Your orders': 'Tilauksesi',
  'Review and prepare customer requests.':
      'Tarkista ja valmistele asiakkaiden tilauspyynnöt.',
  'Track requests and pickup details.':
      'Seuraa tilauspyyntöjä ja noutotietoja.',
  'No orders yet': 'Ei vielä tilauksia',
  'Reject': 'Hylkää',
  'Accept': 'Hyväksy',
  'Mark ready for pickup': 'Merkitse noutovalmiiksi',
  'Mark collected': 'Merkitse noudetuksi',
  'Cancel request': 'Peruuta pyyntö',
  'Requested': 'Pyydetty',
  'Accepted': 'Hyväksytty',
  'Rejected': 'Hylätty',
  'Ready for pickup': 'Valmis noudettavaksi',
  'Completed': 'Valmis',
  'Cancelled': 'Peruutettu',
  'Good morning': 'Hyvää huomenta',
  'Good day': 'Hyvää päivää',
  'Good evening': 'Hyvää iltaa',
  'Manage your products, fulfil orders, and share your farm page.':
      'Hallinnoi tuotteita, käsittele tilauksia ja jaa tilasi sivua.',
  'Your farm': 'Tilasi',
  'Notifications': 'Ilmoitukset',
  'Follow': 'Seuraa',
  'Following': 'Seurataan',
  'follower': 'seuraaja',
  'followers': 'seuraajaa',
  'Notifications are coming next': 'Ilmoitukset ovat tulossa seuraavaksi',
  'Hot Sales': 'Pikamyynnit',
  'Add product': 'Lisää tuote',
  'Add Hot Sale': 'Lisää pikamyynti',
  'Manage Hot Sales': 'Hallitse pikamyyntejä',
  'Add seasonal products, update stock, and choose farm or REKO pickup.':
      'Lisää kausituotteita, päivitä varastoa ja valitse nouto tilalta tai REKOsta.',
  'Add your first seasonal product for nearby customers.':
      'Lisää ensimmäinen kausituotteesi lähialueen asiakkaille.',
  'Could not load Hot Sales': 'Pikamyyntejä ei voitu ladata',
  'Manage': 'Hallitse',
  'Quantity': 'Määrä',
  'Product': 'Tuote',
  'Choose what customers will see on your farm page.':
      'Valitse, mitä asiakkaat näkevät tilasi sivulla.',
  'What are you selling?': 'Mitä myyt?',
  'Choose a product.': 'Valitse tuote.',
  'Stock and price': 'Varasto ja hinta',
  'Tell us how much is available and how you sell it.':
      'Kerro saatavilla oleva määrä ja myyntitapa.',
  'How do you sell it?': 'Miten myyt tuotetta?',
  'Available now': 'Saatavilla nyt',
  'Quantity available': 'Saatavilla oleva määrä',
  'Enter how many selected units are available.':
      'Anna, kuinka monta valittua yksikköä on saatavilla.',
  'Price per': 'Hinta per',
  'Kilogram (kg)': 'Kilogramma (kg)',
  'Gram (g)': 'Gramma (g)',
  'Litre (L)': 'Litra (l)',
  'Piece': 'Kappale',
  'Bunch': 'Nippu',
  'Box': 'Laatikko',
  'Dozen (12 pieces)': 'Tusina (12 kappaletta)',
  'My own unit': 'Oma yksikkö',
  'Customer price': 'Asiakashinta',
  'Product details': 'Tuotetiedot',
  'A clear description helps customers decide.':
      'Selkeä kuvaus auttaa asiakasta valitsemaan.',
  'Description': 'Kuvaus',
  'Add a short description.': 'Lisää lyhyt kuvaus.',
  'Production details (optional)': 'Tuotantotiedot (valinnainen)',
  'Add product photo': 'Lisää tuotekuva',
  'Available from': 'Saatavilla',
  'Choose farm pickup, one or more REKO rings, or both.':
      'Valitse nouto tilalta, yksi tai useampi REKO-rinki tai molemmat.',
  'At the farm': 'Tilalta',
  'Customers collect from your registered farm address.':
      'Asiakkaat noutavat rekisteröidystä tilan osoitteesta.',
  'Search REKO rings across Finland': 'Hae REKO-rinkejä koko Suomesta',
  'Suggested near you': 'Suositukset lähelläsi',
  'Could not load REKO rings': 'REKO-rinkejä ei voitu ladata',
  'Publish Hot Sale': 'Julkaise pikamyynti',
  'Enter a value greater than zero.': 'Anna nollaa suurempi arvo.',
  'Add one product photo.': 'Lisää yksi tuotekuva.',
  'Choose farm pickup or at least one REKO ring.':
      'Valitse nouto tilalta tai vähintään yksi REKO-rinki.',
  'litre': 'litra',
  'piece': 'kappale',
  'bunch': 'nippu',
  'box': 'laatikko',
  'dozen': 'tusina',
  'Every week': 'Joka viikko',
  'Every other week': 'Joka toinen viikko',
  'Monday': 'Maanantai',
  'Tuesday': 'Tiistai',
  'Wednesday': 'Keskiviikko',
  'Thursday': 'Torstai',
  'Friday': 'Perjantai',
  'Saturday': 'Lauantai',
  'Sunday': 'Sunnuntai',
  'Product name': 'Tuotteen nimi',
  'For example: Fresh new potatoes': 'Esimerkiksi: Tuoreet uudet perunat',
  'Enter a product name.': 'Anna tuotteen nimi.',
  'Category': 'Tuoteryhmä',
  'Original language': 'Alkuperäinen kieli',
  'Detect automatically': 'Tunnista automaattisesti',
  'We keep your original and create searchable English, Finnish, and Swedish translations.':
      'Säilytämme alkuperäisen tekstin ja luomme haettavat englannin-, suomen- ja ruotsinkieliset käännökset.',
  'Original text': 'Alkuperäinen teksti',
  'AI translated from': 'Tekoälyn kääntämä kielestä',
  'See original': 'Näytä alkuperäinen',
  'Other / custom unit': 'Muu / oma yksikkö',
  'Custom selling unit': 'Oma myyntiyksikkö',
  'For example: bag, tray, jar, or 5 kg box':
      'Esimerkiksi: pussi, tarjotin, purkki tai 5 kg laatikko',
  'Enter your selling unit.': 'Anna myyntiyksikkö.',
  'Customer price per': 'Asiakashinta per',
  'custom unit': 'oma yksikkö',
};

const _sv = <String, String>{
  'verificationEmailPrefix': 'Vi skickade en 6-siffrig kod till\n',
  'codeExpiresPrefix': 'Koden går ut om ',
  'resendPrefix': 'Skicka igen om ',
  'uploadPrefix': 'Ladda upp ',
  'consumerPlusPrefix': 'Konsument + ',
  'helloPrefix': 'Hej, ',
  'requiredSuffix': ' är obligatoriskt.',
  'Choose from photos': 'Välj bland bilder',
  'Take a photo': 'Ta ett foto',
  'A new verification code was sent.': 'En ny verifieringskod skickades.',
  'Password reset email sent.':
      'E-post för lösenordsåterställning har skickats.',
  'Your verification request was sent for review.':
      'Din verifieringsbegäran skickades för granskning.',
  'Sign-in could not be completed. Please try again.':
      'Inloggningen kunde inte slutföras. Försök igen.',
  'Enter the 6-digit verification code.':
      'Ange den 6-siffriga verifieringskoden.',
  'Your session expired. Please sign in again.':
      'Din session har gått ut. Logga in igen.',
  'Confirm your location before continuing.':
      'Bekräfta din plats innan du fortsätter.',
  'Enter your email address first.': 'Ange först din e-postadress.',
  'Add a written response before submitting.':
      'Lägg till ett skriftligt svar innan du skickar.',
  'Confirm your details before submitting.':
      'Bekräfta dina uppgifter innan du skickar.',
  'Each verification file must be 8 MB or smaller.':
      'Varje verifieringsfil får vara högst 8 MB.',
  'Upload a PDF, JPG, PNG, or WEBP file.':
      'Ladda upp en PDF-, JPG-, PNG- eller WEBP-fil.',
  'This email already has an account. Try signing in.':
      'Det finns redan ett konto med denna e-postadress. Försök logga in.',
  'The email or password is incorrect.':
      'E-postadressen eller lösenordet är felaktigt.',
  'Choose a stronger password.': 'Välj ett starkare lösenord.',
  'Check your internet connection.': 'Kontrollera din internetanslutning.',
  'This email uses another sign-in method. Use that method first.':
      'Denna e-postadress använder en annan inloggningsmetod. Använd den först.',
  'This sign-in method is not enabled in Firebase yet.':
      'Denna inloggningsmetod är ännu inte aktiverad.',
  'Authentication failed. Please try again.':
      'Autentiseringen misslyckades. Försök igen.',
  'This phone number is already registered. Sign in to the existing account or use another number.':
      'Telefonnumret är redan registrerat. Logga in på det befintliga kontot eller använd ett annat nummer.',
  'Confirm your registered location first.':
      'Bekräfta först din registrerade plats.',
  'A few details now, then make FRSH yours.':
      'Bara några uppgifter till, sedan är FRSH ditt.',
  'This is how local customers will recognise you.':
      'Så här kommer lokala kunder att känna igen dig.',
  'Your local food journey starts now.': 'Din lokala matresa börjar nu.',
  'FRSH member': 'FRSH-medlem',
  'Business profile': 'Företagsprofil',
  'Seller profile': 'Säljarprofil',
  'Resubmit for verification': 'Skicka in igen för verifiering',
  'Where is your business?': 'Var finns ditt företag?',
  'Add the storefront, farm or operating location customers should discover.':
      'Lägg till butiken, gården eller verksamhetsplatsen som kunderna ska hitta.',
  'Finding this address…': 'Söker efter adressen…',
  'Select your date of birth.': 'Välj ditt födelsedatum.',
  'Select a business type.': 'Välj en företagstyp.',
  'Enter a valid phone number.': 'Ange ett giltigt telefonnummer.',
  'Required': 'Obligatoriskt',
  'DRAFT': 'UTKAST',
  'NEEDS CHANGES': 'ÄNDRINGAR KRÄVS',
  'REJECTED': 'AVVISAD',
  'VERIFIED': 'VERIFIERAD',
  'PENDING': 'VÄNTAR',
  'Discover': 'Upptäck',
  'Market': 'Marknad',
  'Profile': 'Profil',
  'Discover is coming next': 'Upptäck-vyn kommer härnäst',
  'Marketplace is coming next': 'Marknaden kommer härnäst',
  'Action required for verification': 'Åtgärd krävs för verifiering',
  'Verification under review': 'Verifieringen granskas',
  'Verification pending': 'Verifieringen väntar på granskning',
  'Verification needs your attention': 'Verifieringen kräver din uppmärksamhet',
  'Verify your seller profile': 'Verifiera din säljarprofil',
  'The verification team needs more information.':
      'Verifieringsteamet behöver mer information.',
  'We will notify you when the review is complete.':
      'Vi meddelar dig när granskningen är klar.',
  'Review the decision and submit a new request.':
      'Granska beslutet och skicka en ny begäran.',
  'Complete verification to unlock seller features.':
      'Slutför verifieringen för att låsa upp säljarfunktionerna.',
  'Verified seller': 'Verifierad säljare',
  'Help customers trust your seller profile by confirming who you are.':
      'Bekräfta vem du är så att kunder kan lita på din säljarprofil.',
  'Your documents were submitted. We will notify you when the review is complete.':
      'Dina dokument har skickats. Vi meddelar dig när granskningen är klar.',
  'No action is needed while the verification team reviews your submission.':
      'Ingen åtgärd behövs medan verifieringsteamet granskar din ansökan.',
  'Submit requested information': 'Skicka begärd information',
  'Submit for verification': 'Skicka för verifiering',
  'Settings': 'Inställningar',
  'Language': 'Språk',
  'Choose the language used throughout the app.':
      'Välj språket som används i hela appen.',
  'English': 'Engelska',
  'Finnish': 'Finska',
  'Swedish': 'Svenska',
  'Active account': 'Aktivt konto',
  'Switch how you are using FRSH. This does not remove either profile.':
      'Byt hur du använder FRSH. Detta tar inte bort någon av profilerna.',
  'Consumer account': 'Konsumentkonto',
  'Business account': 'Företagskonto',
  'Side-hustler account': 'Småproducentkonto',
  'Discover and buy local food': 'Upptäck och köp lokal mat',
  'Manage your registered business profile':
      'Hantera din registrerade företagsprofil',
  'Manage your producer profile': 'Hantera din producentprofil',
  'YOUR SETUP': 'DIN KONFIGURATION',
  'WELCOME': 'VÄLKOMMEN',
  'One account for discovering, making and selling local food.':
      'Ett konto för att upptäcka, producera och sälja lokal mat.',
  'Continue with Google': 'Fortsätt med Google',
  'or': 'eller',
  'Continue with email': 'Fortsätt med e-post',
  'Secure sign-in • your saved setup resumes automatically':
      'Säker inloggning • din sparade konfiguration fortsätter automatiskt',
  'YOUR ACCOUNT': 'DITT KONTO',
  'Create your account': 'Skapa ditt konto',
  'Welcome back': 'Välkommen tillbaka',
  'Use the email and password you registered with.':
      'Använd e-postadressen och lösenordet du registrerade.',
  'Create account': 'Skapa konto',
  'Sign in': 'Logga in',
  'Email address': 'E-postadress',
  'Enter a valid email address.': 'Ange en giltig e-postadress.',
  'Password': 'Lösenord',
  'Use at least 8 characters.': 'Använd minst 8 tecken.',
  'Confirm password': 'Bekräfta lösenord',
  'Passwords do not match.': 'Lösenorden matchar inte.',
  'Forgot password?': 'Glömt lösenordet?',
  'Continue': 'Fortsätt',
  'STEP 1 OF 4': 'STEG 1 AV 4',
  'How will you use FRSH?': 'Hur kommer du att använda FRSH?',
  'You can also be a consumer. Choose only one type of seller profile.':
      'Du kan också vara konsument. Välj endast en typ av säljarprofil.',
  'Consumer': 'Konsument',
  'Discover fresh food and trusted makers nearby.':
      'Upptäck färsk mat och pålitliga producenter i närheten.',
  'Side-hustle producer': 'Småskalig producent',
  'Sell small-batch, seasonal or homemade products.':
      'Sälj småskaliga, säsongsbetonade eller hemlagade produkter.',
  'INDIVIDUAL': 'PRIVATPERSON',
  'Registered business': 'Registrerat företag',
  'Build a verified storefront for your farm or company.':
      'Skapa en verifierad butik för din gård eller ditt företag.',
  'BUSINESS': 'FÖRETAG',
  'Enter verification code': 'Ange verifieringskod',
  'Check your inbox and spam folder. The code is sent by FRSH Nearby and expires soon.':
      'Kontrollera inkorgen och skräpposten. Koden skickas av FRSH Nearby och går snart ut.',
  'Verification code': 'Verifieringskod',
  'Verify email': 'Verifiera e-post',
  'Use a different email': 'Använd en annan e-postadress',
  'STEP 2 OF 4': 'STEG 2 AV 4',
  'Create your public profile': 'Skapa din offentliga profil',
  'Tell us about you': 'Berätta om dig',
  'We use this to make your experience feel local.':
      'Vi använder detta för att göra din upplevelse lokal.',
  'Full name': 'Fullständigt namn',
  'Verified email address': 'Verifierad e-postadress',
  'Date of birth *': 'Födelsedatum *',
  'Select date': 'Välj datum',
  'Display name (public)': 'Visningsnamn (offentligt)',
  'Short introduction': 'Kort presentation',
  'What do you make or grow?': 'Vad tillverkar eller odlar du?',
  'STEP 3 OF 4': 'STEG 3 AV 4',
  'Business details': 'Företagsuppgifter',
  'These details help us verify your storefront. Only your public name and address area are shown.':
      'Uppgifterna hjälper oss att verifiera din butik. Endast ditt offentliga namn och adressområde visas.',
  'Business name': 'Företagsnamn',
  'Farm name': 'Gårdsnamn',
  'Business ID': 'Företags-ID',
  'VAT number': 'Momsnummer',
  'Business type *': 'Företagstyp *',
  'Farm': 'Gård',
  'Food producer': 'Livsmedelsproducent',
  'Retailer': 'Återförsäljare',
  'Other': 'Annat',
  'Business address': 'Företagsadress',
  'City': 'Ort',
  'Zip code': 'Postnummer',
  'Review application': 'Granska ansökan',
  'FINAL STEP': 'SISTA STEGET',
  'Everything looks fresh': 'Allt ser bra ut',
  'Confirm what we saved. You can edit anything before continuing.':
      'Bekräfta det vi sparat. Du kan redigera allt innan du fortsätter.',
  'Account type': 'Kontotyp',
  'Public identity': 'Offentlig identitet',
  'Registered location': 'Registrerad plats',
  'Seller verification': 'Säljarverifiering',
  'Available later from your profile': 'Tillgängligt senare från din profil',
  'Your private account and verification details are never displayed publicly.':
      'Dina privata konto- och verifieringsuppgifter visas aldrig offentligt.',
  'Create my account': 'Skapa mitt konto',
  'By continuing, you agree to our Terms and Privacy Policy.':
      'Genom att fortsätta godkänner du våra villkor och vår integritetspolicy.',
  'Welcome to FRSH nearby!': 'Välkommen till FRSH nearby!',
  'Your profile is ready. You can apply for seller verification later from your profile.':
      'Din profil är klar. Du kan ansöka om säljarverifiering senare från din profil.',
  'Explore FRSH': 'Utforska FRSH',
  'YOUR PROFILE': 'DIN PROFIL',
  'Edit profile': 'Redigera profil',
  'Account details': 'Kontouppgifter',
  'Apply for verification': 'Ansök om verifiering',
  'Sign out': 'Logga ut',
  'Edit': 'Redigera',
  'Delete': 'Ta bort',
  'Available': 'Tillgänglig',
  'Unavailable': 'Inte tillgänglig',
  'Sold out': 'Slutsåld',
  'Visible to customers': 'Syns för kunder',
  'Hidden from customers': 'Dold för kunder',
  'Make available': 'Gör tillgänglig',
  'Make unavailable': 'Gör otillgänglig',
  'Use ⋮ menu': 'Använd ⋮-menyn',
  'Set exact quantity': 'Ange exakt mängd',
  'Decimals are allowed for weight and liquid.':
      'Decimaler är tillåtna för vikt och vätska.',
  'Quantity button step': 'Steg för mängdknappar',
  'Amount added or removed with each + or − tap.':
      'Mängden som läggs till eller tas bort vid varje tryck på + eller −.',
  'Save': 'Spara',
  'Try again': 'Försök igen',
  'Cancel': 'Avbryt',
  'Edit Hot Sale': 'Redigera Hot Sale-produkt',
  'Save changes': 'Spara ändringar',
  'Delete product?': 'Ta bort produkten?',
  'This will remove': 'Detta tar bort',
  'from your Hot Sales list.': 'från din Hot Sales-lista.',
  'No products yet. Add your first seasonal product.':
      'Inga produkter ännu. Lägg till din första säsongsprodukt.',
  'Business registration': 'Företagsregistrering',
  'Tax or VAT document': 'Skatte- eller momsdokument',
  'Proof of identity': 'Identitetsbevis',
  'Activity or location proof': 'Bevis på verksamhet eller plats',
  'Business registration proof': 'Bevis på företagsregistrering',
  'Other document': 'Annat dokument',
  'Verification document': 'Verifieringsdokument',
  'proof of identity': 'identitetsbevis',
  'business registration proof': 'bevis på företagsregistrering',
  'tax or VAT document': 'skatte- eller momsdokument',
  'activity or location proof': 'bevis på verksamhet eller plats',
  'other document': 'annat dokument',
  'verification document': 'verifieringsdokument',
  'Requested update': 'Begärd uppdatering',
  'Verification proof': 'Verifieringsbevis',
  'Review the details above, attach proof, then confirm they are correct.':
      'Granska uppgifterna ovan, bifoga bevis och bekräfta sedan att de är korrekta.',
  'No new file upload requested.': 'Ingen ny filuppladdning begärdes.',
  'Response to reviewer': 'Svar till granskaren',
  'Answer the question or explain what you changed.':
      'Besvara frågan eller förklara vad du ändrade.',
  'I confirm these details are accurate and I am responsible for the products I sell.':
      'Jag bekräftar att uppgifterna är korrekta och ansvarar för produkterna jag säljer.',
  'PDF or image upload': 'Ladda upp PDF eller bild',
  'Add': 'Lägg till',
  'Remove': 'Ta bort',
  'Add profile photo · optional': 'Lägg till profilbild · valfritt',
  'Search country or code': 'Sök land eller kod',
  'Phone number *': 'Telefonnummer *',
  'Phone number': 'Telefonnummer',
  'Business location': 'Företagets plats',
  'Seller location': 'Säljarens plats',
  'Your location': 'Din plats',
  'This location powers nearby discovery.':
      'Denna plats används för att hitta utbud i närheten.',
  'Turn on location services, or enter your address manually.':
      'Aktivera platstjänster eller ange adressen manuellt.',
  'Location permission was not granted. Enter your address manually.':
      'Platsbehörighet beviljades inte. Ange adressen manuellt.',
  'We found your position but not its street address. Enter it manually.':
      'Vi hittade din position men inte gatuadressen. Ange den manuellt.',
  'We could not locate this address. Check it and try again.':
      'Vi kunde inte hitta adressen. Kontrollera den och försök igen.',
  'Where do you make or sell?': 'Var producerar eller säljer du?',
  'Choose your location': 'Välj din plats',
  'We use this location to show nearby producers, products and Hot Sales. Use your current location or choose another area.':
      'Vi använder platsen för att visa producenter, produkter och Hot Sales i närheten. Använd din nuvarande plats eller välj ett annat område.',
  'Add your farm, kitchen, pickup point or production location.':
      'Lägg till din gård, ditt kök, din upphämtningsplats eller produktionsplats.',
  'Suggest from my current position': 'Föreslå från min nuvarande position',
  'Optional shortcut only. Edit the address below if you are not currently at the seller location.':
      'Endast en valfri genväg. Redigera adressen nedan om du inte är på säljarens plats just nu.',
  'Use your current location or choose another location below.':
      'Använd din nuvarande plats eller välj en annan plats nedan.',
  'Zoom in and tap your preferred location. The marker and address fields will update.':
      'Zooma in och tryck på den plats du föredrar. Markören och adressfälten uppdateras.',
  'Street address and number *': 'Gatuadress och nummer *',
  'For example: Market Street 12': 'Till exempel: Marknadsgatan 12',
  'Building, block, unit or floor':
      'Byggnad, trappuppgång, lägenhet eller våning',
  'For example: Building B, unit 4': 'Till exempel: byggnad B, lägenhet 4',
  'Address lookup © OpenStreetMap contributors. Please confirm the street before saving.':
      'Adressökning © OpenStreetMaps bidragsgivare. Bekräfta gatan innan du sparar.',
  'Postal code *': 'Postnummer *',
  'City *': 'Ort *',
  'Country *': 'Land *',
  'Confirm seller location': 'Bekräfta säljarens plats',
  'Confirm location': 'Bekräfta plats',
  'Fresh food near you': 'Färsk mat nära dig',
  'Discover local producers': 'Upptäck lokala producenter',
  'Seasonal food and small businesses, close to home.':
      'Säsongsmat och småföretag nära hemmet.',
  'Browse by category': 'Bläddra efter kategori',
  'Vegetables': 'Grönsaker',
  'Bakery': 'Bageri',
  'Eggs & dairy': 'Ägg och mejeri',
  'Nearby sellers': 'Säljare i närheten',
  'Local sellers and their products will appear here as the marketplace opens.':
      'Lokala säljare och deras produkter visas här när marknadsplatsen öppnar.',
  'SELLER WORKSPACE': 'SÄLJARVY',
  'Your business': 'Ditt företag',
  'Active orders': 'Aktiva beställningar',
  'This month': 'Den här månaden',
  'Quick actions': 'Snabbåtgärder',
  'Start selling locally': 'Börja sälja lokalt',
  'Products, inventory, and incoming orders will live in this seller workspace.':
      'Produkter, lager och inkommande beställningar samlas i den här säljarvyn.',
  'My profile': 'Min profil',
  'Personal details': 'Personuppgifter',
  'Your local marketplace is coming next':
      'Din lokala marknadsplats kommer härnäst',
  'Seller orders are coming next': 'Säljarbeställningar kommer härnäst',
  'Home': 'Hem',
  'Dashboard': 'Översikt',
  'Orders': 'Beställningar',
  'Explore': 'Utforska',
  'Current location': 'Nuvarande plats',
  'Use current location': 'Använd nuvarande plats',
  'Hide farm tile': 'Dölj gårdskortet',
  'Show farm tile': 'Visa gårdskortet',
  'Could not load nearby Hot Sales':
      'Kunde inte läsa in snabbförsäljning i närheten',
  'Hot Sales nearby': 'snabbförsäljningar i närheten',
  'km away': 'km bort',
  'available': 'tillgängligt',
  'product in basket': 'produkt i korgen',
  'products in basket': 'produkter i korgen',
  'Request order': 'Skicka beställningsförfrågan',
  'Sending request…': 'Skickar förfrågan…',
  'Subtotal': 'Delsumma',
  'kilogram': 'kilogram',
  'gram': 'gram',
  'other': 'annan',
  'Your basket': 'Din korg',
  'Pickup place': 'Upphämtningsplats',
  'Farm pickup': 'Hämtning på gården',
  'Select a pickup place.': 'Välj en upphämtningsplats.',
  'Total': 'Totalt',
  'Order request sent to the farm.':
      'Beställningsförfrågan skickades till gården.',
  'Sold by': 'Säljs av',
  'Available at': 'Tillgänglig på',
  'Translated from': 'Översatt från',
  'Original': 'Original',
  'No farm Hot Sales within 50 km yet':
      'Ingen snabbförsäljning från gårdar inom 50 km ännu',
  'New seasonal products will appear here.': 'Nya säsongsprodukter visas här.',
  'Farm orders': 'Gårdsbeställningar',
  'Your orders': 'Dina beställningar',
  'Review and prepare customer requests.':
      'Granska och förbered kundernas förfrågningar.',
  'Track requests and pickup details.':
      'Följ förfrågningar och upphämtningsdetaljer.',
  'No orders yet': 'Inga beställningar ännu',
  'Reject': 'Avvisa',
  'Accept': 'Godkänn',
  'Mark ready for pickup': 'Markera som klar för upphämtning',
  'Mark collected': 'Markera som hämtad',
  'Cancel request': 'Avbryt förfrågan',
  'Requested': 'Begärd',
  'Accepted': 'Godkänd',
  'Rejected': 'Avvisad',
  'Ready for pickup': 'Klar för upphämtning',
  'Completed': 'Slutförd',
  'Cancelled': 'Avbruten',
  'Good morning': 'God morgon',
  'Good day': 'God dag',
  'Good evening': 'God kväll',
  'Manage your products, fulfil orders, and share your farm page.':
      'Hantera produkter, behandla beställningar och dela din gårdssida.',
  'Your farm': 'Din gård',
  'Notifications': 'Aviseringar',
  'Follow': 'Följ',
  'Following': 'Följer',
  'follower': 'följare',
  'followers': 'följare',
  'Notifications are coming next': 'Aviseringar kommer härnäst',
  'Hot Sales': 'Snabbförsäljning',
  'Add product': 'Lägg till produkt',
  'Add Hot Sale': 'Lägg till snabbförsäljning',
  'Manage Hot Sales': 'Hantera snabbförsäljning',
  'Add seasonal products, update stock, and choose farm or REKO pickup.':
      'Lägg till säsongsprodukter, uppdatera lagret och välj gårds- eller REKO-hämtning.',
  'Add your first seasonal product for nearby customers.':
      'Lägg till din första säsongsprodukt för kunder i närheten.',
  'Could not load Hot Sales': 'Kunde inte läsa in snabbförsäljning',
  'Manage': 'Hantera',
  'Quantity': 'Mängd',
  'Product': 'Produkt',
  'Choose what customers will see on your farm page.':
      'Välj vad kunderna ser på din gårdssida.',
  'What are you selling?': 'Vad säljer du?',
  'Choose a product.': 'Välj en produkt.',
  'Stock and price': 'Lager och pris',
  'Tell us how much is available and how you sell it.':
      'Ange hur mycket som finns och hur du säljer det.',
  'How do you sell it?': 'Hur säljer du det?',
  'Available now': 'Tillgängligt nu',
  'Quantity available': 'Tillgängligt antal',
  'Enter how many selected units are available.':
      'Ange hur många av den valda enheten som finns tillgängliga.',
  'Price per': 'Pris per',
  'Kilogram (kg)': 'Kilogram (kg)',
  'Gram (g)': 'Gram (g)',
  'Litre (L)': 'Liter (l)',
  'Piece': 'Styck',
  'Bunch': 'Knippe',
  'Box': 'Låda',
  'Dozen (12 pieces)': 'Dussin (12 stycken)',
  'My own unit': 'Egen enhet',
  'Customer price': 'Kundpris',
  'Product details': 'Produktinformation',
  'A clear description helps customers decide.':
      'En tydlig beskrivning hjälper kunderna att välja.',
  'Description': 'Beskrivning',
  'Add a short description.': 'Lägg till en kort beskrivning.',
  'Production details (optional)': 'Produktionsinformation (valfritt)',
  'Add product photo': 'Lägg till produktbild',
  'Available from': 'Tillgänglig från',
  'Choose farm pickup, one or more REKO rings, or both.':
      'Välj hämtning på gården, en eller flera REKO-ringar eller båda.',
  'At the farm': 'På gården',
  'Customers collect from your registered farm address.':
      'Kunderna hämtar på din registrerade gårdsadress.',
  'Search REKO rings across Finland': 'Sök REKO-ringar i hela Finland',
  'Suggested near you': 'Förslag nära dig',
  'Could not load REKO rings': 'Kunde inte läsa in REKO-ringar',
  'Publish Hot Sale': 'Publicera snabbförsäljning',
  'Enter a value greater than zero.': 'Ange ett värde större än noll.',
  'Add one product photo.': 'Lägg till en produktbild.',
  'Choose farm pickup or at least one REKO ring.':
      'Välj hämtning på gården eller minst en REKO-ring.',
  'litre': 'liter',
  'piece': 'styck',
  'bunch': 'knippe',
  'box': 'låda',
  'dozen': 'dussin',
  'Every week': 'Varje vecka',
  'Every other week': 'Varannan vecka',
  'Monday': 'Måndag',
  'Tuesday': 'Tisdag',
  'Wednesday': 'Onsdag',
  'Thursday': 'Torsdag',
  'Friday': 'Fredag',
  'Saturday': 'Lördag',
  'Sunday': 'Söndag',
  'Product name': 'Produktnamn',
  'For example: Fresh new potatoes': 'Till exempel: Färsk nypotatis',
  'Enter a product name.': 'Ange ett produktnamn.',
  'Category': 'Kategori',
  'Original language': 'Originalspråk',
  'Detect automatically': 'Identifiera automatiskt',
  'We keep your original and create searchable English, Finnish, and Swedish translations.':
      'Vi sparar originalet och skapar sökbara engelska, finska och svenska översättningar.',
  'Original text': 'Originaltext',
  'AI translated from': 'AI-översatt från',
  'See original': 'Visa original',
  'Other / custom unit': 'Annan / egen enhet',
  'Custom selling unit': 'Egen försäljningsenhet',
  'For example: bag, tray, jar, or 5 kg box':
      'Till exempel: påse, bricka, burk eller 5 kg låda',
  'Enter your selling unit.': 'Ange din försäljningsenhet.',
  'Customer price per': 'Kundpris per',
  'custom unit': 'egen enhet',
};
