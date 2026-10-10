import '../engine/engine.dart';

/// A puzzle chosen because solving it needs a particular technique.
class PuzzleEntry {
  const PuzzleEntry({
    required this.id,
    required this.title,
    required this.text,
    required this.technique,
  });

  /// Stable key for saving progress. Never change it once a puzzle ships.
  final String id;

  final String title;

  /// 81 characters, `0` for blanks.
  final String text;

  /// The hardest technique the puzzle cannot be solved without (see
  /// `ratePuzzle`).
  final Technique technique;

  int get level => technique.level;
}

const puzzleLibrary = [
  PuzzleEntry(
    id: 'fullHouse',
    title: 'Full House practice',
    text: '364050218857124306091368074129480753038715420475293081782639145546871932913542867',
    technique: Technique.fullHouse,
  ),
  PuzzleEntry(
    id: 'fullHouse-2',
    title: 'Full House practice 2',
    text: '581473629479862315263510700124698570800035062635720198946257831318946257752381946',
    technique: Technique.fullHouse,
  ),
  PuzzleEntry(
    id: 'nakedSingle',
    title: 'Warm-up',
    text: '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
    technique: Technique.nakedSingle,
  ),
  PuzzleEntry(
    id: 'nakedSingle-2',
    title: 'Naked Single practice 2',
    text: '748052139106074050253891674002930086805046390630718542924560013501403967367109025',
    technique: Technique.nakedSingle,
  ),
  PuzzleEntry(
    id: 'hiddenSingle',
    title: 'Hidden Single practice',
    text: '030150000567030008902000000006003890350000601001796502693805100145300080728060050',
    technique: Technique.hiddenSingle,
  ),
  PuzzleEntry(
    id: 'hiddenSingle-2',
    title: 'Hidden Single practice 2',
    text: '605279100902314007014000000400032000358091006201608503860120700000480301007003000',
    technique: Technique.hiddenSingle,
  ),
  PuzzleEntry(
    id: 'pointingPair',
    title: 'Locked in a line',
    text: '4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......',
    technique: Technique.pointingPair,
  ),
  PuzzleEntry(
    id: 'pointingPair-2',
    title: 'Pointing Pair/Triple practice 2',
    text: '091000438400018009007034125300095071004000800006783000040856010600000000700040380',
    technique: Technique.pointingPair,
  ),
  PuzzleEntry(
    id: 'boxLineReduction',
    title: 'Box/Line Reduction practice',
    text: '000600500610000987000000602030000029507800403081090005000908000700040000904050000',
    technique: Technique.boxLineReduction,
  ),
  PuzzleEntry(
    id: 'boxLineReduction-2',
    title: 'Box/Line Reduction practice 2',
    text: '080000462150000090006800007091060030700250900500003020000002000900000670600970000',
    technique: Technique.boxLineReduction,
  ),
  PuzzleEntry(
    id: 'nakedPair',
    title: 'Twin cells',
    text: '050003100000700004000900008807000200030000060502000010120000070000060001079300600',
    technique: Technique.nakedPair,
  ),
  PuzzleEntry(
    id: 'nakedPair-2',
    title: 'Naked Pair practice 2',
    text: '027000960835091720600200001060070209098400610002906050050009008000084000900500170',
    technique: Technique.nakedPair,
  ),
  PuzzleEntry(
    id: 'hiddenPair',
    title: 'Hidden twins',
    text: '000000000068000704074000800006000970000930080000000062590340000010080005400500000',
    technique: Technique.hiddenPair,
  ),
  PuzzleEntry(
    id: 'hiddenPair-2',
    title: 'Hidden Pair practice 2',
    text: '009000405040300200006090031300809050000605000100070608000004000070900003600038040',
    technique: Technique.hiddenPair,
  ),
  PuzzleEntry(
    id: 'nakedTriple',
    title: 'Naked Triple practice',
    text: '080090047500000080407138060750004006000309000300000000020900008000081000100570090',
    technique: Technique.nakedTriple,
  ),
  PuzzleEntry(
    id: 'nakedTriple-2',
    title: 'Naked Triple practice 2',
    text: '800023090345600012200000860000000040006800000100900006400700009902008030000000407',
    technique: Technique.nakedTriple,
  ),
  PuzzleEntry(
    id: 'hiddenTriple',
    title: 'Hidden Triple practice',
    text: '630000100040060050800107040900200000000640000087000000003092000500000300006035070',
    technique: Technique.hiddenTriple,
  ),
  PuzzleEntry(
    id: 'hiddenTriple-2',
    title: 'Hidden Triple practice 2',
    text: '020605080010000020534000900000301000301000000000076050900000002005007000206400097',
    technique: Technique.hiddenTriple,
  ),
  PuzzleEntry(
    id: 'xWing',
    title: 'X-Wing practice',
    text: '107000000093084060000000900401007093009005700738400100000038000000000007000279040',
    technique: Technique.xWing,
  ),
  PuzzleEntry(
    id: 'xWing-2',
    title: 'X-Wing practice 2',
    text: '000900600905000080062050971000000038504100000000060210703608000400000020206500000',
    technique: Technique.xWing,
  ),
  PuzzleEntry(
    id: 'skyscraper',
    title: 'Tall towers',
    text: '709004006000200009000100780031000000000000450570080002010540900843001000000000000',
    technique: Technique.skyscraper,
  ),
  PuzzleEntry(
    id: 'skyscraper-2',
    title: 'Skyscraper practice 2',
    text: '000003200000294075025000000080420019100900000290370060007615832000700000600039000',
    technique: Technique.skyscraper,
  ),
  PuzzleEntry(
    id: 'yWing',
    title: 'Three-cell wing',
    text: '050000006200000004000006050080000000310054000600020090007000013830700900005230080',
    technique: Technique.yWing,
  ),
  PuzzleEntry(
    id: 'yWing-2',
    title: 'Y-Wing practice 2',
    text: '900580000804020750025000490080070900407006000500341000200038170040900036000000040',
    technique: Technique.yWing,
  ),
  PuzzleEntry(
    id: 'swordfish',
    title: 'Swordfish practice',
    text: '640002070008900304930000000850007600000000020000003840480020509160035080072800030',
    technique: Technique.swordfish,
  ),
  PuzzleEntry(
    id: 'swordfish-2',
    title: 'Swordfish practice 2',
    text: '042000000350040000001635002000060070604090310003000006000709800900000041000080000',
    technique: Technique.swordfish,
  ),
  PuzzleEntry(
    id: 'nakedQuad',
    title: 'Naked Quad practice',
    text: '200060004604000000000004053000710090100020000702800006071680320300000800008300100',
    technique: Technique.nakedQuad,
  ),
  PuzzleEntry(
    id: 'nakedQuad-2',
    title: 'Naked Quad practice 2',
    text: '000000090000400830040670000070010600005040209920000010067000905000790080000000000',
    technique: Technique.nakedQuad,
  ),
  PuzzleEntry(
    id: 'hiddenQuad',
    title: 'Hidden Quad practice',
    text: '030000902004009000000500080600104000205800034070002050000010047000007600000300000',
    technique: Technique.hiddenQuad,
  ),
  PuzzleEntry(
    id: 'xyzWing',
    title: 'Pivot with two wings',
    text: '100000308800940007005300000507008000000000000000060023000009040001470600000002800',
    technique: Technique.xyzWing,
  ),
  PuzzleEntry(
    id: 'xyzWing-2',
    title: 'XYZ-Wing practice 2',
    text: '000072310600104090000008760096020103708006000002000580000000000003001800007980000',
    technique: Technique.xyzWing,
  ),
  PuzzleEntry(
    id: 'uniqueRectangle',
    title: 'Deadly pattern',
    text: '024001000000040000900070008100300900600009504000000200007000030800000050090150760',
    technique: Technique.uniqueRectangle,
  ),
  PuzzleEntry(
    id: 'uniqueRectangle-2',
    title: 'Unique Rectangle practice 2',
    text: '000090310000083900400000087046020000010609270200000000800100000001000640005460100',
    technique: Technique.uniqueRectangle,
  ),
  PuzzleEntry(
    id: 'wWing',
    title: 'Linked twins',
    text: '400006700000300000097000040060000005079080000500900003002003010810400000000060800',
    technique: Technique.wWing,
  ),
  PuzzleEntry(
    id: 'wWing-2',
    title: 'W-Wing practice 2',
    text: '006100030007050204083006009030520740000000800804007000000905400058400000000700010',
    technique: Technique.wWing,
  ),
  PuzzleEntry(
    id: 'simpleColoring',
    title: 'Two colours',
    text: '904003006000000500000008300028075009070000001500090000006082000200000670090030002',
    technique: Technique.simpleColoring,
  ),
  PuzzleEntry(
    id: 'simpleColoring-2',
    title: 'Simple Coloring practice 2',
    text: '031000006000059001000002000100507009890030020000060500010000075900000060407800000',
    technique: Technique.simpleColoring,
  ),
  PuzzleEntry(
    id: 'jellyfish',
    title: 'Jellyfish practice',
    text: '700503190000007025200000000030000900024700000000900053605801000000060080007000000',
    technique: Technique.jellyfish,
  ),
];
