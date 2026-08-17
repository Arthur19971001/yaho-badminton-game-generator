import 'package:flutter_test/flutter_test.dart';
import 'package:yaho_badminton_game_generator/src/features/members/domain/korean_search.dart';

void main() {
  group('choseongOf', () {
    test('extracts initial consonants from Hangul syllables', () {
      expect(choseongOf('김가영'), 'ㄱㄱㅇ');
      expect(choseongOf('철수'), 'ㅊㅅ');
    });

    test('passes non-Hangul characters through unchanged', () {
      expect(choseongOf('민수2'), 'ㅁㅅ2');
    });
  });

  group('matchesKoreanQuery', () {
    test('empty query matches everything', () {
      expect(matchesKoreanQuery('철수', ''), isTrue);
      expect(matchesKoreanQuery('철수', '   '), isTrue);
    });

    test('plain substring search works normally', () {
      expect(matchesKoreanQuery('김철수', '철수'), isTrue);
      expect(matchesKoreanQuery('김철수', '영희'), isFalse);
      expect(matchesKoreanQuery('Alice', 'ali'), isTrue);
    });

    test('choseong-only query matches via initial consonants', () {
      expect(matchesKoreanQuery('가영', 'ㄱㅇ'), isTrue);
      expect(matchesKoreanQuery('김철수', 'ㄱㅊㅅ'), isTrue);
      expect(matchesKoreanQuery('김철수', 'ㄱㅊ'), isTrue); // prefix match
      expect(matchesKoreanQuery('김철수', 'ㅊㅅ'), isTrue); // substring match
      expect(matchesKoreanQuery('김철수', 'ㅇㅇ'), isFalse);
    });

    test('a query mixing full syllables and choseong falls back to plain substring', () {
      expect(matchesKoreanQuery('김철수', '김ㅊ'), isFalse);
    });
  });
}
