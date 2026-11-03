import 'package:flutter/material.dart';

import '../data/api.dart';
import '../data/config.dart';
import '../theme.dart';
import '../widgets/product_card.dart';
import '../widgets/ui.dart';
import '../data/texts.dart';

class SearchScreen extends StatefulWidget {
  final String initial;
  const SearchScreen({super.key, this.initial = ''});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _c = TextEditingController(text: widget.initial);
  late String q = widget.initial;

  List<String> get suggestions {
    final l = Cfg.i.strings('pages.search_suggestions');
    return l.isEmpty ? const ['مثقب', 'جلاخة', tx('search.1', 'شحن'), tx('search.2', 'كمبريسور'), tx('search.3', 'منشار'), tx('search.4', 'مولدة'), tx('search.5', 'طقم')] : l;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final res = Api.i.search(q);
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, top + 12, 16, 8),
          child: Row(children: [
            Pressable(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.line)),
                child: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Hero(
                tag: 'search',
                child: Material(
                  color: Colors.transparent,
                  child: TextField(
                    controller: _c,
                    autofocus: widget.initial.isEmpty,
                    onChanged: (v) => setState(() => q = v),
                    style: T.b(15, w: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: tx('search.6', 'ابحث في منتجات كوفيكس'),
                      hintStyle: T.b(14.5, c: C.muted),
                      prefixIcon: const Icon(Icons.search_rounded, color: C.muted),
                      suffixIcon: q.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => setState(() {
                                _c.clear();
                                q = '';
                              }),
                            ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.line)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: C.line)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: C.accent, width: 1.5)),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
        Expanded(
          child: q.trim().isEmpty
              ? ListView(padding: const EdgeInsets.all(20), children: [
                  Text(tx('search.7', 'عمليات بحث شائعة'), style: T.h(16)),
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 10, children: [
                    for (final s in suggestions)
                      Pressable(
                        onTap: () => setState(() {
                          _c.text = s;
                          q = s;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(30), border: Border.all(color: C.line)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.trending_up_rounded, size: 16, color: C.accent),
                            const SizedBox(width: 6),
                            Text(s, style: T.b(13.5, w: FontWeight.w600)),
                          ]),
                        ),
                      ),
                  ]),
                ])
              : res.isEmpty
                  ? Center(child: Text('لا توجد نتائج لـ "$q"', style: T.b(14, c: C.muted)))
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                        mainAxisExtent: 304,
                      ),
                      itemCount: res.length,
                      itemBuilder: (c, i) => ProductCard(res[i], heroTag: 'search'),
                    ),
        ),
      ]),
    );
  }
}
