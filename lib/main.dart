import 'package:flutter/material.dart';

import 'godel_dpll.dart';

void main() => runApp(const GodelDpllApp());

class GodelDpllApp extends StatelessWidget {
  const GodelDpllApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gödel-DPLL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _ctrl = TextEditingController(text: 'p -> (q -> (p & q))');
  bool _pinning = false;
  bool _refining = false;
  DpllResult? _result;
  Map<String, DpllResult>? _comparison;
  String? _error;

  static const _examples = <String, String>{
    'Prelinearity': '(p -> q) | (q -> p)',
    'Excluded middle': 'p | ~p',
    'Double negation': '~~p -> p',
    '∧-introduction': 'p -> (q -> (p & q))',
    'Peirce': '((p -> q) -> p) -> p',
    'Distributivity': '(p & (q | r)) -> ((p & q) | (p & r))',
  };

  void _run() {
    setState(() {
      _error = null;
      _result = null;
      _comparison = null;
    });
    Formula? phi;
    try {
      phi = Parser.parse(_ctrl.text);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final res = godelDpll(phi!, pinningRules: _pinning, refiningRules: _refining);
    final cmp = {
      'Var-Trichotomy only': godelDpll(phi),
      '+ pinning rules': godelDpll(phi, pinningRules: true),
      '+ pinning + refining': godelDpll(phi, pinningRules: true, refiningRules: true),
    };
    setState(() {
      _result = res;
      _comparison = cmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final res = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Gödel-DPLL — validity in propositional Gödel logic')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _ctrl,
            decoration: InputDecoration(
              labelText: 'Formula   (operators: ~  &  |  ->   constants: T  F)',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _run(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final e in _examples.entries)
                ActionChip(label: Text(e.key), onPressed: () => setState(() => _ctrl.text = e.value)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            children: [
              FilterChip(
                label: const Text('pinning rules (Conj-Bot, Conj-Min, Disj-Top, Disj-Max)'),
                selected: _pinning,
                onSelected: (v) => setState(() => _pinning = v),
              ),
              FilterChip(
                label: const Text('refining rules (Conj-NonTop, Impl-Top-Sharp, Impl-Eq-Branch)'),
                selected: _refining,
                onSelected: (v) => setState(() => _refining = v),
              ),
              FilledButton.icon(onPressed: _run, icon: const Icon(Icons.play_arrow), label: const Text('Decide')),
            ],
          ),
          const SizedBox(height: 16),
          if (res != null) ...[
            _ResultCard(res),
            const SizedBox(height: 16),
            if (_comparison != null) _ComparisonTable(_comparison!),
            const SizedBox(height: 16),
            Text('Search tree', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            _TreeView(res.tree),
          ],
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final DpllResult res;
  const _ResultCard(this.res);

  @override
  Widget build(BuildContext context) {
    final s = res.stats;
    final k = res.sub.vars.length;
    final c = res.sub.connectiveCount;
    final hBound = c < (k + 2) * (k + 1) ~/ 2 ? c : (k + 2) * (k + 1) ~/ 2;
    final cm = res.countermodel;
    return Card(
      color: res.valid ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(res.valid ? 'VALID' : 'NOT-VALID',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            if (cm != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('countermodel: ${cm.entries.map((e) => '${e.key} = ${_fmt(e.value)}').join(', ')}'),
              ),
            const SizedBox(height: 8),
            Text('nodes ${s.nodes}  ·  branching steps ${s.branchings}  ·  depth ${s.maxDepth}  '
                '(bound h = min(c(φ) = $c, pairs = ${(k + 2) * (k + 1) ~/ 2}) = $hBound)  ·  '
                'propagation firings ${s.ruleFirings}  ·  |Sub(φ)| = ${res.sub.n - 2}, k = $k'),
          ],
        ),
      ),
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  final Map<String, DpllResult> cmp;
  const _ComparisonTable(this.cmp);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Strategy comparison (Remark 5.20)', style: Theme.of(context).textTheme.titleMedium),
            DataTable(
              columns: const [
                DataColumn(label: Text('strategy')),
                DataColumn(label: Text('nodes'), numeric: true),
                DataColumn(label: Text('branchings'), numeric: true),
                DataColumn(label: Text('depth'), numeric: true),
                DataColumn(label: Text('firings'), numeric: true),
              ],
              rows: [
                for (final e in cmp.entries)
                  DataRow(cells: [
                    DataCell(Text(e.key)),
                    DataCell(Text('${e.value.stats.nodes}')),
                    DataCell(Text('${e.value.stats.branchings}')),
                    DataCell(Text('${e.value.stats.maxDepth}')),
                    DataCell(Text('${e.value.stats.ruleFirings}')),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeView extends StatelessWidget {
  final SearchNode node;
  final int depth;
  const _TreeView(this.node, {this.depth = 0});

  @override
  Widget build(BuildContext context) {
    final color = switch (node.status) {
      NodeStatus.closed => Colors.red,
      NodeStatus.open => Colors.green,
      NodeStatus.active => Colors.grey,
    };
    final label = switch (node.status) {
      NodeStatus.closed => 'closed',
      NodeStatus.open => 'open',
      NodeStatus.active => 'unexplored',
    };
    return Padding(
      padding: EdgeInsets.only(left: depth * 20.0, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4)),
              color: color.withOpacity(0.06),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.circle, size: 10, color: color),
                  const SizedBox(width: 6),
                  Text('${node.added.join(',  ')}   ', style: const TextStyle(fontFamily: 'monospace')),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Text('   (${node.ruleFirings} propagation firings)',
                      style: const TextStyle(color: Colors.black54, fontSize: 12)),
                ]),
                if (node.rule != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 2),
                    child: Text('⟶ ${node.rule}', style: const TextStyle(fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
          for (final ch in node.children) _TreeView(ch, depth: depth + 1),
        ],
      ),
    );
  }
}

String _fmt(double x) {
  // exact rational labels for the values produced by extraction
  for (var d = 1; d <= 12; d++) {
    for (var num = 0; num <= d; num++) {
      if ((x - num / d).abs() < 1e-9) return d == 1 ? '$num' : '$num/$d';
    }
  }
  return x.toStringAsFixed(3);
}
