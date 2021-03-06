import 'package:analyzer/dart/element/element.dart';
import 'package:build_test/build_test.dart';
import 'package:floor_annotation/floor_annotation.dart' as annotations;
import 'package:floor_generator/misc/constants.dart';
import 'package:floor_generator/processor/entity_processor.dart';
import 'package:floor_generator/processor/error/entity_processor_error.dart';
import 'package:floor_generator/processor/field_processor.dart';
import 'package:floor_generator/value_object/entity.dart';
import 'package:floor_generator/value_object/foreign_key.dart';
import 'package:floor_generator/value_object/fts.dart';
import 'package:floor_generator/value_object/index.dart';
import 'package:floor_generator/value_object/primary_key.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

import '../fakes.dart';
import '../test_utils.dart';

void main() {
  test('Process entity', () async {
    final classElement = await createClassElement('''
      @entity
      class Person {
        @primaryKey
        final int id;
      
        final String name;
      
        Person(this.id, this.name);
      }
    ''');

    final actual = EntityProcessor(classElement, {}).process();

    const name = 'Person';
    final fields = classElement.fields
        .map((fieldElement) => FieldProcessor(fieldElement, null).process())
        .toList();
    final primaryKey = PrimaryKey([fields[0]], false);
    const foreignKeys = <ForeignKey>[];
    const indices = <Index>[];
    const constructor = "Person(row['id'] as int, row['name'] as String)";
    const valueMapping = "<String, Object?>{'id': item.id, 'name': item.name}";
    final expected = Entity(
      classElement,
      name,
      fields,
      primaryKey,
      foreignKeys,
      indices,
      false,
      constructor,
      valueMapping,
      null,
    );
    expect(actual, equals(expected));
  });

  test('Process entity with compound primary key', () async {
    final classElement = await createClassElement('''
      @Entity(primaryKeys: ['id', 'name'])
      class Person {
        final int id;
      
        final String name;
      
        Person(this.id, this.name);
      }
    ''');

    final actual = EntityProcessor(classElement, {}).process();

    const name = 'Person';
    final fields = classElement.fields
        .map((fieldElement) => FieldProcessor(fieldElement, null).process())
        .toList();
    final primaryKey = PrimaryKey(fields, false);
    const foreignKeys = <ForeignKey>[];
    const indices = <Index>[];
    const constructor = "Person(row['id'] as int, row['name'] as String)";
    const valueMapping = "<String, Object?>{'id': item.id, 'name': item.name}";
    final expected = Entity(
      classElement,
      name,
      fields,
      primaryKey,
      foreignKeys,
      indices,
      false,
      constructor,
      valueMapping,
      null,
    );
    expect(actual, equals(expected));
  });

  group('foreign keys', () {
    test('foreign key holds correct values', () async {
      final classElements = await _createClassElements('''
        @entity
        class Person {
          @primaryKey
          final int id;
          
          final String name;
        
          Person(this.id, this.name);
        }
        
        @Entity(
          foreignKeys: [
            ForeignKey(
              childColumns: ['owner_id'],
              parentColumns: ['id'],
              entity: Person,
              onUpdate: ForeignKeyAction.cascade
              onDelete: ForeignKeyAction.setNull,
            )
          ],
        )
        class Dog {
          @primaryKey
          final int id;
        
          final String name;
        
          @ColumnInfo(name: 'owner_id')
          final int ownerId;
        
          Dog(this.id, this.name, this.ownerId);
        }
    ''');

      final actual =
          EntityProcessor(classElements[1], {}).process().foreignKeys[0];

      final expected = ForeignKey(
        'Person',
        ['id'],
        ['owner_id'],
        annotations.ForeignKeyAction.cascade,
        annotations.ForeignKeyAction.setNull,
      );
      expect(actual, equals(expected));
    });

    test('error with wrong onUpdate Annotation', () async {
      final classElements = await _createClassElements('''
          @entity
          class Person {
            @primaryKey
            final int id;
            
            final String name;
          
            Person(this.id, this.name);
          }
          
          @Entity(
            foreignKeys: [
              ForeignKey(
                childColumns: ['owner_id'],
                parentColumns: ['id'],
                entity: Person,
                onUpdate: null
                onDelete: ForeignKeyAction.setNull,
              )
            ],
          )
          class Dog {
            @primaryKey
            final int id;
          
            final String name;
          
            @ColumnInfo(name: 'owner_id')
            final int ownerId;
          
            Dog(this.id, this.name, this.ownerId);
          }
      ''');

      final processor = EntityProcessor(classElements[1], {});
      expect(
          processor.process,
          throwsInvalidGenerationSourceError(
              EntityProcessorError(classElements[1]).wrongForeignKeyAction(
                  FakeDartObject(), ForeignKeyField.onUpdate)));
    });
  });

  group('fts keys', () {
    test('fts key with fts3', () async {
      final classElements = await _createClassElements('''
        
        @entity
        @fts3
        class MailInfo {
          @primaryKey
          @ColumnInfo(name: 'rowid')
          final int id;
        
          final String text;
        
          MailInfo(this.id, this.text);
        }
    ''');

      final actual = EntityProcessor(classElements[0], {}).process().fts;

      final Fts expected = Fts3('simple', []);

      expect(actual, equals(expected));
    });
  });

  group('fts keys', () {
    test('fts key with fts4', () async {
      final classElements = await _createClassElements('''
        
        @entity
        @fts4
        class MailInfo {
          @primaryKey
          @ColumnInfo(name: 'rowid')
          final int id;
        
          final String text;
        
          MailInfo(this.id, this.text);
        }
    ''');

      final actual = EntityProcessor(classElements[0], {}).process().fts;

      final Fts expected = Fts4('simple', []);

      expect(actual, equals(expected));
    });
  });

  test('Process entity with "WITHOUT ROWID"', () async {
    final classElement = await createClassElement('''
      @Entity(withoutRowid: true)
      class Person {
        @primaryKey
        final int id;
      
        final String name;
      
        Person(this.id, this.name);
      }
    ''');

    final actual = EntityProcessor(classElement, {}).process();

    const name = 'Person';
    final fields = classElement.fields
        .map((fieldElement) => FieldProcessor(fieldElement, null).process())
        .toList();
    final primaryKey = PrimaryKey([fields[0]], false);
    const foreignKeys = <ForeignKey>[];
    const indices = <Index>[];
    const constructor = "Person(row['id'] as int, row['name'] as String)";
    final expected = Entity(
      classElement,
      name,
      fields,
      primaryKey,
      foreignKeys,
      indices,
      true,
      constructor,
      "<String, Object?>{'id': item.id, 'name': item.name}",
      null,
    );
    expect(actual, equals(expected));
  });

  group('Value mapping', () {
    test('Non-nullable boolean value mapping', () async {
      final classElement = await createClassElement('''
      @entity
      class Person {
        @primaryKey
        final int id;
      
        final bool isSomething;
      
        Person(this.id, this.isSomething);
      }
    ''');

      final actual = EntityProcessor(classElement, {}).process().valueMapping;

      const expected = '<String, Object?>{'
          "'id': item.id, "
          "'isSomething': item.isSomething ? 1 : 0"
          '}';
      expect(actual, equals(expected));
    });

    test('Nullable boolean value mapping', () async {
      final classElement = await createClassElement('''
      @entity
      class Person {
        @primaryKey
        final int id;
      
        final bool? isSomething;
      
        Person(this.id, this.isSomething);
      }
    ''');

      final actual = EntityProcessor(classElement, {}).process().valueMapping;

      const expected = '<String, Object?>{'
          "'id': item.id, "
          "'isSomething': item.isSomething == null ? null : (item.isSomething! ? 1 : 0)"
          '}';
      expect(actual, equals(expected));
    });
  });
}

Future<List<ClassElement>> _createClassElements(final String classes) async {
  final library = await resolveSource('''
      library test;
      
      import 'package:floor_annotation/floor_annotation.dart';
      
      $classes
      ''', (resolver) async {
    return LibraryReader((await resolver.findLibraryByName('test'))!);
  });

  return library.classes.toList();
}
