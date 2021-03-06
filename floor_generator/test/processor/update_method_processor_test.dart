import 'package:floor_generator/processor/update_method_processor.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('Collects on conflict strategy', () async {
    final insertionMethod = await '''
      @Update(onConflict: OnConflictStrategy.replace)
      Future<void> updatePerson(Person person);
    '''
        .asDaoMethodElement();
    final entities = await getPersonEntity();

    final actual =
        UpdateMethodProcessor(insertionMethod, [entities]).process().onConflict;

    expect(actual, equals('OnConflictStrategy.replace'));
  });

  test('Error on wrong onConflict value', () async {
    final insertionMethod = await '''
      @Update(onConflict: OnConflictStrategy.doesnotexist)
      Future<void> updatePerson(Person person);
   '''
        .asDaoMethodElement();
    final entities = await getPersonEntity();

    final actual =
        () => UpdateMethodProcessor(insertionMethod, [entities]).process();

    expect(actual, throwsA(const TypeMatcher<InvalidGenerationSourceError>()));
  });
}
