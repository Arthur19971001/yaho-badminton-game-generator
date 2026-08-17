/// Korean-aware search matching: supports plain substring search, and
/// "초성" (chosung/initial-consonant) search where e.g. typing "ㄱㅇ" matches
/// a name like "가영" (가=ㄱ, 영=ㅇ). Used to search the member roster by
/// name without requiring the full spelling.
library;

const _choseongList = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ',
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

const _hangulSyllableBase = 0xAC00; // '가'
const _hangulSyllableLast = 0xD7A3; // '힣'
const _jamoPerChoseong = 21 * 28; // 중성(21) * 종성(28) combinations

/// Returns [text] with every complete Hangul syllable replaced by its
/// choseong (initial consonant); non-Hangul characters pass through as-is.
/// e.g. "김가영" -> "ㄱㄱㅇ".
String choseongOf(String text) {
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    if (rune >= _hangulSyllableBase && rune <= _hangulSyllableLast) {
      final index = (rune - _hangulSyllableBase) ~/ _jamoPerChoseong;
      buffer.write(_choseongList[index]);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// True if every character in [text] is a standalone choseong consonant
/// (e.g. "ㄱㅇ"), meaning it should be matched via [choseongOf] rather than
/// as a literal substring.
bool _isChoseongOnlyQuery(String text) {
  if (text.isEmpty) return false;
  for (final rune in text.runes) {
    if (!_choseongList.contains(String.fromCharCode(rune))) return false;
  }
  return true;
}

/// Whether [name] matches a user-typed [query], supporting both plain
/// substring search and Korean choseong search. An empty query matches
/// everything.
bool matchesKoreanQuery(String name, String query) {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return true;

  if (_isChoseongOnlyQuery(trimmed)) {
    return choseongOf(name).contains(trimmed);
  }
  return name.toLowerCase().contains(trimmed.toLowerCase());
}
