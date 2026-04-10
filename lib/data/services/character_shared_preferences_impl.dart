import 'dart:convert';

import 'package:injustice_app/domain/usecases/character_usecases_impl.dart';

import '../../core/failure/failure.dart';
import '../../core/typedefs/types_defs.dart';
import 'character_local_storage_interface.dart';
import '../../domain/models/character_entity.dart';
import '../../domain/models/character_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/patterns/result.dart';

final class CharacterSharedPreferencesService
    implements ICharacterLocalStorage {
  // Chave de armazenamento para os personagens
  static const String _storageKey = 'characters';

  @override
  Future<CharacterResult> deleteCharacter(String id) async {
    final result = await getAllCharacters();

    return result.fold(
      onSuccess: (characters) async {
        final index = characters.indexWhere((c) => c.id == id);

        if (index == -1) {
          return Error(ApiLocalFailure('Personagem com ID $id não encontrado'));
        }

        final deletedCharacter = characters[index];

        final updatedCharacters = [...characters];
        updatedCharacters.removeAt(index);
        await _saveCharacters(updatedCharacters);

        return Success(deletedCharacter);
      },
      onFailure: (failure) async {
        return Error(
          ApiLocalFailure(
            'Shared Preferences - Erro ao deletar personagem com id: $id',
          ),
        );
      },
    );
  }

  @override
  Future<ListCharacterResult> getAllCharacters() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = prefs.getString(_storageKey);

      if (result == null || result.isEmpty) {
        return Error(EmptyResultFailure());
      }

      final decoded = jsonDecode(result) as List<dynamic>;

      final characters = decoded
          .map((e) => CharacterMapper.fromMap(e as Map<String, dynamic>))
          .toList();

      return Success(characters);
    } catch (e) {
      return Error(
        ApiLocalFailure('Shared Preferences - Erro ao obter personagens: $e'),
      );
    }
  }

  @override
  Future<CharacterResult> getCharacterById(String id) async {
    final result = await getAllCharacters();

    return result.fold(
      onSuccess: (characters) {
        final index = characters.indexWhere((c) => c.id == id);
        return index == -1
            ? Error(ApiLocalFailure('Personagem com ID $id não encontrado'))
            : Success(characters[index]);
      },
      onFailure: (failure) async {
        return Error(
          ApiLocalFailure(
            'Shared Preferences - Erro ao obter personagem com id: $id',
          ),
        );
      },
    );
  }

  @override
  Future<CharacterResult> updateCharacter(Character character) async {
    try {
      final currentResult = await getAllCharacters();

      return await currentResult.fold(
        onSuccess: (characters) async {
          final index = characters.indexWhere((c) => c.id == character.id);

          if (index == -1) {
            return Error(
              ApiLocalFailure('Personagem não encontrado para atualização'),
            );
          }

          characters[index] = character;
          await _saveCharacters(characters);
          return Success(character);
        },
        onFailure: (failure) async {
          if (failure is EmptyResultFailure) {
            return Error(EmptyCharacterList());
          } else {
            return Error(ApiLocalFailure());
          }
        },
      );
    } catch (e) {
      return Error(
        ApiLocalFailure('Shared Preferences - Erro ao editar personagem: $e'),
      );
    }
  }

  @override
  Future<CharacterResult> saveCharacter(Character character) async {
    try {
      final currentResult = await getAllCharacters();

      return await currentResult.fold(
        onSuccess: (characters) async {
          final updatedCharacters = [...characters, character];
          await _saveCharacters(updatedCharacters);
          return Success(character);
        },
        onFailure: (failure) async {
          if (failure is EmptyResultFailure) {
            await _saveCharacters([character]);
            return Success(character);
          }

          return Error(ApiLocalFailure());
        },
      );
    } catch (e) {
      return Error(
        ApiLocalFailure('Shared Preferences - Erro ao salvar personagem: $e'),
      );
    }
  }

  /// Salva os personagens no storage
  Future<void> _saveCharacters(List<Character> characters) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = json.encode(
        characters.map((c) => CharacterMapper.toMap(c)).toList(),
      );
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      throw ApiLocalFailure('Erro ao salvar personagens: $e');
    }
  }
}
