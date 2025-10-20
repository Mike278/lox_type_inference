import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart';

void main() async {
  final keep = [
    'tour_0_basics.lox',
    'tour_1_records.lox',
    'tour_2_variants.lox',
    'tour_3_functions.lox',
    'tour_4_errors.lox',
    'tour_5_lists.lox',
    'advent_of_code_2024_day_1.lox',
    'advent_of_code_2024_day_2.lox',
    'advent_of_code_2024_day_3.lox',
    'advent_of_code_2021_day_2.lox',
    'util/lists.lox',
    'util/functions.lox',
    'util/numeric.lox',
    'util/strings.lox',
  ];
  final skip = {
    'foo/relative.lox',
    'foo/up.lox',
    'basic_test.lox',
    'if.lox',
    'if_expr_err_block_missing_semi.lox',
    'if_expr_err_record_implicit_label.lox',
    'imports.lox',
    'lambdas.lox',
    'lists.lox',
    'make_counter.lox',
    'patterns.lox',
    'records.lox',
    'scoping.lox',
    'tag_pattern_err_let.lox',
    'tag_pattern_err_let_no_payload.lox',
    'tag_pattern_err_param.lox',
    'tag_pattern_err_param_no_payload.lox',
    'tags.lox',
    'return_expr.lox',
    'fwd_decl.lox',
  };
  bool shouldKeep(String name) {
    if (keep.contains(name)) return true;
    if (skip.contains(name)) return false;
    throw 'new example "$name" needs classifying';
  }
  final sampleFiles = Directory('../examples')
      .list(recursive: true)
      .where((e) => e is File)
      .map((e) => (split(e.path).skip(2).join('/'), e as File));
  final samples = {
      await for (final (name, file) in sampleFiles)
        if (shouldKeep(name))
          name: await file.readAsString()
    };
    final sorted = samples.keys.sorted(
      (a, b) => keep.indexOf(a).compareTo(keep.indexOf(b))
    );

    File('web/code_samples.dart').writeAsString(
      """

// 
// ACHTUNG!
// ALLES TURISTEN UND NONTEKNISCHEN LOOKENSPEEPERS!
// DAS KOMPUTERMASCHINE IST NICHT FÜR DER GEFINGERPOKEN UND MITTENGRABEN! ODERWISE IST EASY TO SCHNAPPEN DER SPRINGENWERK, BLOWENFUSEN UND POPPENCORKEN MIT SPITZENSPARKEN.
// IST NICHT FÜR GEWERKEN BEI DUMMKOPFEN. DER RUBBERNECKEN SIGHTSEEREN KEEPEN DAS COTTONPICKEN HÄNDER IN DAS POCKETS MUSS.
// ZO RELAXEN UND WATSCHEN DER BLINKENLICHTEN.
// 
// 
// (its generated code dont touch )
//
//
//
// (https://en.wikipedia.org/wiki/Blinkenlights)
//
//

extension type SampleName(String _) implements String {}
extension type SampleContent(String _) implements String {}
typedef Sample = (SampleName, SampleContent);
extension SampleAPI on Sample {
  SampleName get name => \$1;
  SampleContent get content => \$2;
}

final samples = [
  ${sorted.map((sampleName) => "(SampleName('$sampleName'),  SampleContent(r'''${samples[sampleName]!}'''))").join(',\n')}
];
""",
    );
}

