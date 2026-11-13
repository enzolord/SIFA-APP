import '../models/diagnosis.dart';

/// Fiches maladies de SIFA.
///
/// Rédigées à partir de manuels vétérinaires et d'études publiées :
///  - MSD Veterinary Manual (coccidiose, maladie de Newcastle, pullorose, typhose aviaire)
///  - OMSA / WOAH (fiche maladie de Newcastle, chapitre typhose et pullorose)
///  - FAO, « Small-scale poultry production » (chapitre santé)
///  - ACIAR, « Controlling Newcastle disease in village chickens » (vaccin I-2)
///  - Notices de médicaments (amprolium, toltrazuril)
///  - Essais sur l'aloe vera, le papayer et le ndolé contre la coccidiose (dont Buea, Cameroun)
///
/// EN ATTENTE DE VALIDATION PAR LE VÉTÉRINAIRE RÉFÉRENT DE SIFA.
/// Les textes sont en français ; l'anglais est dans tools/translations_en.py.

/// Niveau de preuve d'un conseil, affiché à côté de chaque remède artisanal.
enum Evidence { proven, limited, unproven, dangerous, commonSense }

const evidenceLabel = <Evidence, String>{
  Evidence.proven: 'Efficace',
  Evidence.limited: 'Preuve limitée',
  Evidence.unproven: 'Non prouvé',
  Evidence.dangerous: 'Dangereux',
  Evidence.commonSense: 'Bon sens',
};

class KbItem {
  const KbItem(this.title, this.body, [this.evidence]);
  final String title;
  final String body;
  final Evidence? evidence;
}

class DiseaseSheet {
  const DiseaseSheet({
    required this.recognize,
    required this.now,
    required this.scientific,
    required this.artisanal,
    required this.prevention,
    required this.confusions,
    this.humanRisk,
  });

  /// Comment reconnaître la maladie.
  final List<KbItem> recognize;

  /// Gestes immédiats, dans l'ordre.
  final List<String> now;

  /// Voie vétérinaire (médicaments, vaccins).
  final List<KbItem> scientific;

  /// Voie artisanale (plantes, pratiques d'élevage), avec niveau de preuve.
  final List<KbItem> artisanal;
  final List<String> prevention;

  /// Maladies ou situations qui donnent des signes proches.
  final List<String> confusions;
  final String? humanRisk;
}

const kbPendingValidation =
    'Fiche rédigée à partir de manuels vétérinaires (MSD, OMSA, FAO). En attente de validation par le vétérinaire référent de SIFA.';

const diseaseSheets = <Disease, DiseaseSheet>{
  // ───────────────────────────── Fiente saine ─────────────────────────────
  Disease.healthy: DiseaseSheet(
    recognize: [
      KbItem('Fiente normale', 'Brune à verdâtre, bien formée, avec un capuchon blanc. Ce blanc est normal : c\'est l\'urine du poulet.'),
      KbItem('Fientes cæcales', 'Quelques fois par jour, la poule fait une fiente plus molle, brun foncé et collante. C\'est normal, ce n\'est pas une diarrhée.'),
      KbItem('Poulets en bonne santé', 'Ils mangent, boivent, se déplacent et ont les plumes lisses.'),
    ],
    now: [
      'Continuez la surveillance habituelle.',
      'Vérifiez l\'eau et l\'aliment chaque jour.',
      'Refaites une analyse si les fientes changent ou si des poulets semblent malades.',
    ],
    scientific: [
      KbItem('Aucun traitement nécessaire', 'Ne donnez pas d\'antibiotique « par sécurité » : cela crée des microbes résistants et laisse des résidus dans la viande et les œufs.'),
      KbItem('Tenez le calendrier de vaccination', 'La vaccination contre la maladie de Newcastle est la protection la plus utile pour une bande saine.'),
    ],
    artisanal: [
      KbItem('Litière sèche et eau propre', 'Ce sont les deux gestes qui évitent le plus de maladies digestives.', Evidence.proven),
      KbItem('Observation quotidienne', 'Regardez les fientes et le comportement chaque matin : un problème vu tôt se règle mieux.', Evidence.commonSense),
    ],
    prevention: [
      'Gardez la litière sèche et le bâtiment bien aéré.',
      'Nettoyez abreuvoirs et mangeoires chaque jour.',
      'Gardez tout nouveau poulet à part pendant 15 jours avant de le mélanger aux autres.',
      'Limitez les visites dans le poulailler.',
    ],
    confusions: [
      'Une fiente d\'aspect normal n\'exclut pas une maladie débutante : fiez-vous aussi au comportement des poulets.',
    ],
  ),

  // ───────────────────────────── Coccidiose ─────────────────────────────
  Disease.coccidiosis: DiseaseSheet(
    recognize: [
      KbItem('Fientes', 'Sang rouge ou brun-rouge dans les fientes, parfois des glaires ou une diarrhée très liquide.'),
      KbItem('Poulets', 'En boule, plumes ébouriffées. Ils mangent moins, boivent beaucoup et maigrissent.'),
      KbItem('Âge', 'Surtout les jeunes poulets, le plus souvent entre 3 et 8 semaines. Les adultes résistent mieux.'),
      KbItem('Cause', 'Un parasite microscopique de l\'intestin, qui se multiplie dans la litière humide.'),
      KbItem('Confirmation', 'Le vétérinaire confirme en regardant les fientes au microscope ou en ouvrant un poulet mort.'),
    ],
    now: [
      'Mettez à part les poulets les plus atteints.',
      'Enlevez la litière mouillée et remettez de la litière sèche.',
      'Donnez de l\'eau propre à volonté : les poulets se déshydratent vite.',
      'Appelez votre vétérinaire pour un traitement anticoccidien dans l\'eau de boisson.',
    ],
    scientific: [
      KbItem('Amprolium dans l\'eau de boisson', 'C\'est le traitement le plus courant. Dose de la notice : 0,012 % dans l\'eau pendant 3 à 5 jours (0,024 % si la maladie est forte), puis 0,006 % pendant 1 à 2 semaines. Les poulets ne doivent boire que cette eau, refaite chaque jour.'),
      KbItem('Toltrazuril', '7 mg par kg de poids vif et par jour dans l\'eau, 2 jours de suite. Délai avant abattage : 16 jours. Interdit chez les poules qui pondent des œufs pour la consommation.'),
      KbItem('Sulfamides', 'Donnés dans l\'eau quand les signes sont visibles, uniquement sur prescription. Respectez le délai d\'attente avant de vendre viande et œufs.'),
      KbItem('Vitamines A et K', 'Ajoutées à l\'eau ou à l\'aliment, elles aident la guérison. La vitamine K limite les saignements.'),
      KbItem('Traitez toute la bande', 'Tous les poulets du bâtiment sont exposés, pas seulement ceux qui ont du sang dans les fientes.'),
      KbItem('Lisez la notice du produit acheté', 'La quantité de poudre ou de liquide à mettre dans l\'eau dépend de la concentration du produit.'),
      KbItem('Pas de mieux en 3 jours ?', 'Faites confirmer le diagnostic : une autre maladie est possible.'),
    ],
    artisanal: [
      KbItem('Litière sèche, abreuvoirs propres', 'Le parasite se multiplie dans la litière humide. Retirer chaque jour les zones mouillées fait baisser la contamination.', Evidence.proven),
      KbItem('Aloe vera dans l\'eau', 'Gel d\'aloe vera frais mélangé à l\'eau de boisson. Dans un essai sur poulets de chair, 5 g par litre d\'eau a réduit le nombre de parasites, et un essai mené à Buea (Cameroun) va dans le même sens. Moins sûr que le médicament : à utiliser en complément ou en attendant le vétérinaire.', Evidence.limited),
      KbItem('Feuilles de papayer', 'Feuilles fraîches pilées, trempées dans l\'eau puis filtrées, données à boire. L\'essai de Buea montre une baisse du nombre de parasites.', Evidence.limited),
      KbItem('Feuilles de ndolé', 'Le ndolé (Vernonia amygdalina) est utilisé de la même façon dans plusieurs pays d\'Afrique. Dans un essai, les poulets traités avec ces plantes ont mieux survécu que les poulets non traités, mais moins bien que ceux qui ont reçu le médicament.', Evidence.limited),
      KbItem('Quand les plantes ne suffisent pas', 'Si les poulets saignent beaucoup ou meurent, il faut l\'anticoccidien du vétérinaire sans attendre.', Evidence.commonSense),
    ],
    prevention: [
      'Litière sèche, bonne aération, pas trop de poulets au mètre carré.',
      'Nettoyez et désinfectez le bâtiment entre deux bandes, puis laissez-le vide quelques jours.',
      'Demandez à votre fournisseur un aliment avec anticoccidien ou des poussins vaccinés contre la coccidiose.',
      'Ne mélangez pas des poussins avec des poulets plus âgés.',
    ],
    confusions: [
      'Entérite nécrotique : diarrhée sombre et morts rapides.',
      'Vers intestinaux.',
      'Salmonellose.',
      'Fientes cæcales normales : brunes et collantes, mais sans sang.',
    ],
  ),

  // ───────────────────────────── Salmonellose ─────────────────────────────
  Disease.salmonella: DiseaseSheet(
    recognize: [
      KbItem('Chez les poussins (pullorose)', 'Diarrhée blanche qui colle et bouche le cloaque. Poussins serrés près de la chaleur, qui piaulent et ne mangent plus. Les morts surviennent surtout pendant les 2 à 3 premières semaines.'),
      KbItem('Chez les adultes (typhose)', 'Diarrhée jaune, poulets abattus, pâles, qui ne mangent plus. Morts en quelques jours et baisse de ponte.'),
      KbItem('Cause', 'Une bactérie, la salmonelle. Elle passe de la poule au poussin par l\'œuf, puis par les fientes, l\'eau, l\'aliment et la litière. Les poux rouges peuvent aussi la transmettre.'),
      KbItem('Confirmation', 'Seule une analyse au laboratoire confirme la maladie. Les signes seuls ne suffisent pas.'),
    ],
    now: [
      'Mettez à part les poulets malades. Retirez et détruisez les morts.',
      'Lavez-vous les mains au savon après chaque contact.',
      'Nettoyez abreuvoirs et mangeoires chaque jour et changez la litière souillée.',
      'Appelez votre vétérinaire : c\'est lui qui choisit l\'antibiotique.',
      'Ne gardez pas d\'œufs de cette bande pour la couvaison.',
    ],
    scientific: [
      KbItem('Antibiotique sur prescription', 'Il réduit les morts, mais ne nettoie pas la bande : les poulets guéris restent porteurs et peuvent contaminer les autres. C\'est pourquoi les manuels vétérinaires ne recommandent pas de traiter des reproducteurs.'),
      KbItem('Analyse avant de choisir', 'Beaucoup de salmonelles résistent aux antibiotiques courants. Une analyse au laboratoire indique celui qui marche.'),
      KbItem('Délai d\'attente', 'Respectez le délai indiqué sur la notice avant de vendre les œufs et la viande.'),
      KbItem('Vaccin contre la typhose', 'Un vaccin existe (souche 9R), donné vers 8 et 16 semaines. Il réduit les pertes sans empêcher l\'infection. Parlez-en à votre vétérinaire.'),
      KbItem('Bande de reproducteurs atteinte', 'La seule solution durable est d\'éliminer les poulets porteurs.'),
    ],
    artisanal: [
      KbItem('Aucune plante ne guérit', 'Aucun remède traditionnel n\'a montré qu\'il guérissait la salmonellose. N\'attendez pas pour appeler le vétérinaire, surtout si des poussins meurent.', Evidence.unproven),
      KbItem('Hygiène stricte', 'Lavez et séchez au soleil abreuvoirs et mangeoires, changez la litière souillée, luttez contre les rats, les souris et les poux rouges.', Evidence.proven),
      KbItem('Chaleur et eau propre pour les poussins', 'Des poussins au chaud, avec de l\'eau propre, résistent mieux. Nettoyez doucement le cloaque collé à l\'eau tiède.', Evidence.commonSense),
      KbItem('Eau légèrement acidifiée', 'Un peu de vinaigre ou de jus de citron dans l\'eau de boisson la rend moins favorable aux salmonelles. C\'est une aide à l\'hygiène, pas un traitement.', Evidence.limited),
    ],
    prevention: [
      'Achetez vos poussins dans un couvoir contrôlé.',
      'Nettoyez et désinfectez le bâtiment entre deux bandes.',
      'Luttez contre les rats, les souris et les poux rouges.',
      'Gardez tout nouveau poulet à part pendant 15 jours.',
      'Donnez toujours une eau propre.',
    ],
    confusions: [
      'Maladie de Gumboro : diarrhée blanchâtre et liquide chez les jeunes de 3 à 6 semaines.',
      'Coccidiose.',
      'Choléra aviaire : fientes grises, jaunes ou vertes.',
      'Poussins qui ont eu froid ou trop chaud : le cloaque peut aussi se coller.',
      'Le blanc d\'une fiente normale : c\'est de l\'urine, pas une diarrhée.',
    ],
    humanRisk:
        'Les salmonelles de la pullorose et de la typhose passent très rarement à l\'homme, mais d\'autres salmonelles des volailles le peuvent. Lavez-vous les mains et cuisez bien la viande et les œufs.',
  ),

  // ───────────────────────────── Maladie de Newcastle ─────────────────────────────
  Disease.newcastle: DiseaseSheet(
    recognize: [
      KbItem('Fientes', 'Diarrhée liquide verdâtre, parfois blanchâtre. Plumes sales autour du cloaque.'),
      KbItem('Respiration', 'Toux, éternuements, respiration difficile et bruyante.'),
      KbItem('Nerfs', 'Cou tordu, tremblements, ailes ou pattes paralysées, poulets qui tournent en rond.'),
      KbItem('Ponte', 'Chute brutale de la ponte. Œufs déformés, à coquille mince ou rugueuse.'),
      KbItem('Mortalité', 'Beaucoup de morts en quelques jours, à tous les âges. Dans une bande non vaccinée, presque tous les poulets peuvent mourir.'),
      KbItem('Délai', 'Les premiers signes apparaissent 2 à 15 jours après la contamination, souvent 5 à 6 jours.'),
      KbItem('Confirmation', 'Seul un laboratoire peut confirmer. La grippe aviaire donne les mêmes signes.'),
    ],
    now: [
      'Isolez tout de suite la bande et interdisez les visites.',
      'Prévenez votre vétérinaire ou les services vétérinaires : c\'est une maladie à déclarer.',
      'Ne vendez, ne donnez et ne déplacez aucun poulet, œuf ou fumier.',
      'Enterrez profondément ou brûlez les poulets morts. Ne les mangez pas.',
      'Lavez-vous les mains et changez de chaussures en sortant du bâtiment.',
    ],
    scientific: [
      KbItem('Aucun médicament ne guérit', 'C\'est un virus. Aucun médicament, ni antibiotique ni antiviral, ne change l\'évolution de la maladie.'),
      KbItem('Antibiotiques : seulement contre les surinfections', 'Le vétérinaire peut en prescrire pour limiter les infections qui s\'ajoutent. Ils ne tuent pas le virus.'),
      KbItem('Ne vaccinez pas des poulets déjà malades', 'Le vaccin protège avant la maladie, il ne soigne pas.'),
      KbItem('Vaccinez les bandes saines', 'Vaccins vivants (souches Hitchner B1 et La Sota) dans l\'eau de boisson ou en goutte dans l\'œil, avec rappels. Pour les poulets de village, le vaccin I-2 résiste à la chaleur : une goutte dans l\'œil, à refaire tous les 4 mois. La protection arrive 7 à 14 jours après.'),
      KbItem('Après la maladie', 'Retirez tout le fumier, nettoyez et désinfectez (eau de Javel, par exemple), puis attendez 21 à 30 jours après le dernier mort avant de remettre des poulets.'),
    ],
    artisanal: [
      KbItem('Ail, piment, plantes', 'Ces remèdes sont très utilisés dans les villages, mais les éleveurs interrogés reconnaissent eux-mêmes qu\'ils marchent mal. Aucun n\'a montré qu\'il sauvait des poulets.', Evidence.unproven),
      KbItem('Lessive ou produit ménager dans l\'eau', 'Ne le faites jamais : c\'est toxique pour les poulets et pour ceux qui mangent leur viande.', Evidence.dangerous),
      KbItem('Soins aux poulets malades', 'Mettez-les à part, au calme, avec de l\'eau et de l\'aliment à portée. Quelques-uns survivent, mais ils restent contagieux.', Evidence.commonSense),
      KbItem('La vraie protection', 'N\'achetez pas de poulets au marché quand la maladie circule, et gardez tout nouveau poulet à part pendant 15 jours.', Evidence.proven),
    ],
    prevention: [
      'Vaccinez toute la bande et faites les rappels à la date prévue.',
      'Gardez tout nouveau poulet à part pendant 15 jours.',
      'Limitez les visites. Nettoyez chaussures, cages et matériel qui viennent d\'un autre élevage.',
      'Le virus survit des mois dans le fumier : retirez-le et désinfectez entre deux bandes.',
    ],
    confusions: [
      'Grippe aviaire : mêmes signes, à déclarer aussi.',
      'Choléra aviaire.',
      'Bronchite infectieuse, coryza, mycoplasmose : signes respiratoires.',
      'Un poulet qui ne mange plus fait des fientes vertes, quelle que soit la maladie.',
    ],
    humanRisk: 'Chez l\'homme, ce virus peut donner une conjonctivite passagère. Lavez-vous les mains après avoir touché les poulets.',
  ),
};
