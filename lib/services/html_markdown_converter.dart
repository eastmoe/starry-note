import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

class HtmlMarkdownConverter {
  const HtmlMarkdownConverter();

  String convert(String source) {
    final withMedia = source.replaceAllMapped(
      RegExp(r'\[audio\b([^\]]*)\](?:\[/audio\])?', caseSensitive: false),
      (match) {
        final attributes = match.group(1) ?? '';
        final url = RegExp(
              r'''(?:src|mp3)\s*=\s*["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(attributes)?.group(1) ??
            RegExp(r'https?://\S+', caseSensitive: false)
                .firstMatch(attributes)
                ?.group(0);
        return url == null
            ? ''
            : '<audio controls src="${_htmlAttribute(url)}"></audio>';
      },
    );
    final fragment = html_parser.parseFragment(withMedia);
    final markdown = fragment.nodes.map((node) => _render(node)).join();
    return markdown
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  String _render(Node node) {
    if (node is Text) return node.data.replaceAll('\u00a0', ' ');
    if (node is! Element) return '';
    final tag = node.localName!.toLowerCase();
    if (const {
      'script',
      'style',
      'form',
      'object',
      'embed',
      'iframe',
      'noscript',
    }.contains(tag)) {
      return '';
    }
    String children() => node.nodes.map(_render).join();
    String block(String value) => '${value.trim()}\n\n';
    switch (tag) {
      case 'p':
      case 'div':
      case 'section':
      case 'article':
      case 'main':
      case 'header':
      case 'footer':
        return block(children());
      case 'br':
        return '\n';
      case 'hr':
        return '\n---\n\n';
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return '${'#' * int.parse(tag.substring(1))} ${children().trim()}\n\n';
      case 'strong':
      case 'b':
        return '**${children().trim()}**';
      case 'em':
      case 'i':
        return '*${children().trim()}*';
      case 'del':
      case 's':
      case 'strike':
        return '~~${children().trim()}~~';
      case 'blockquote':
        final value =
            children().trim().split('\n').map((line) => '> $line').join('\n');
        return '$value\n\n';
      case 'pre':
        final code = node.text.trimRight();
        final language = node
                .querySelector('code')
                ?.classes
                .firstWhere(
                  (value) => value.startsWith('language-'),
                  orElse: () => '',
                )
                .replaceFirst('language-', '') ??
            '';
        return '```$language\n$code\n```\n\n';
      case 'code':
        final code = node.text.replaceAll('`', '\\`');
        return '`$code`';
      case 'a':
        final href = node.attributes['href']?.trim() ?? '';
        final label = children().trim().isEmpty ? href : children().trim();
        return href.isEmpty ? label : '[$label](${_markdownUrl(href)})';
      case 'img':
        final src = node.attributes['src']?.trim() ?? '';
        if (src.isEmpty) return '';
        final alt = (node.attributes['alt'] ?? '').replaceAll(']', r'\]');
        final title = node.attributes['title'];
        final suffix = title == null || title.isEmpty
            ? ''
            : ' "${title.replaceAll('"', r'\"')}"';
        return '![$alt](${_markdownUrl(src)}$suffix)';
      case 'figure':
        return block(children());
      case 'figcaption':
        final caption = children().trim();
        return caption.isEmpty ? '' : '\n*$caption*\n';
      case 'ul':
        return _renderList(node, false);
      case 'ol':
        return _renderList(node, true);
      case 'li':
        return children();
      case 'table':
        return _renderTable(node);
      case 'audio':
      case 'video':
        final src = node.attributes['src'] ??
            node.querySelector('source')?.attributes['src'] ??
            '';
        if (src.isEmpty) return '';
        return '<$tag controls src="${_htmlAttribute(src)}"></$tag>\n\n';
      case 'source':
        return '';
      default:
        return children();
    }
  }

  String _renderList(Element element, bool ordered) {
    final items = element.children.where((child) => child.localName == 'li');
    var index = 0;
    final lines = <String>[];
    for (final item in items) {
      index++;
      final prefix = ordered ? '$index. ' : '- ';
      final content = item.nodes.map(_render).join().trim();
      final indented = content.replaceAll('\n', '\n  ');
      lines.add('$prefix$indented');
    }
    return '${lines.join('\n')}\n\n';
  }

  String _renderTable(Element table) {
    final rows = table
        .querySelectorAll('tr')
        .map((row) {
          return row.children
              .where((cell) => cell.localName == 'th' || cell.localName == 'td')
              .map((cell) => cell.text.trim().replaceAll('|', r'\|'))
              .toList();
        })
        .where((row) => row.isNotEmpty)
        .toList();
    if (rows.isEmpty) return '';
    final width = rows.map((row) => row.length).reduce((a, b) => a > b ? a : b);
    List<String> padded(List<String> row) => [
          ...row,
          ...List.filled(width - row.length, ''),
        ];
    final output = <String>[
      '| ${padded(rows.first).join(' | ')} |',
      '| ${List.filled(width, '---').join(' | ')} |',
      ...rows.skip(1).map((row) => '| ${padded(row).join(' | ')} |'),
    ];
    return '${output.join('\n')}\n\n';
  }

  String _markdownUrl(String value) => value.replaceAll(' ', '%20');
  static String _htmlAttribute(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;');
}
