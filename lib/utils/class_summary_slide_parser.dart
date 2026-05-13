import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// One slide of HTML (as stored in class_summaries) plus optional narration.
class ClassSummarySlide {
  const ClassSummarySlide({required this.outerHtml, this.narration});

  final String outerHtml;
  final String? narration;
}

/// Mirrors [Portal 2 new]/application/views/user/classsummary/view.php slide logic.
List<ClassSummarySlide> buildClassSummarySlides(String rawHtml) {
  final cleaned = rawHtml.replaceAll('????', '');
  final doc = html_parser.parse(cleaned);
  final root = doc.body ?? doc.documentElement;
  if (root == null) {
    return [ClassSummarySlide(outerHtml: '<div class="slide">$cleaned</div>')];
  }

  var slides = root.getElementsByClassName('slide').toList();

  if (slides.isEmpty) {
    final inner = root.innerHtml.trim();
    if (inner.isEmpty) {
      return const [ClassSummarySlide(outerHtml: '<div class="slide"></div>')];
    }
    final parts = inner.split(RegExp(r'(?=<h[12][>\s])', caseSensitive: false));
    slides = <Element>[];
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final frag = html_parser.parseFragment('<div class="slide">$t</div>');
      if (frag.children.isNotEmpty) slides.add(frag.children.first);
    }
    if (slides.isEmpty) {
      final frag = html_parser.parseFragment('<div class="slide">$inner</div>');
      if (frag.children.isNotEmpty) slides.add(frag.children.first);
    }
  }

  if (slides.length >= 2 &&
      slides[0].classes.contains('gcse-title-slide') &&
      slides.length > 1) {
    final first = slides[0];
    final second = slides[1];
    final mergeWrap = Element.tag('div')..classes.add('css-slide-merged-content');
    mergeWrap.innerHtml = second.innerHtml;
    final narr = second.attributes['data-narration'];
    if (narr != null && narr.isNotEmpty) {
      first.attributes['data-narration'] = narr;
    }
    first.classes.add('gcse-title-merged');
    first.children.add(mergeWrap);
    second.remove();
    slides = [first, ...slides.skip(2)];
  }

  return slides.map((e) {
    final speech = _slideNarrationText(e);
    return ClassSummarySlide(
      outerHtml: e.outerHtml,
      narration: speech.isEmpty ? null : speech,
    );
  }).toList();
}

String _slideNarrationText(Element e) {
  final n = e.attributes['data-narration']?.trim();
  if (n != null && n.isNotEmpty) return n;
  return e.text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
