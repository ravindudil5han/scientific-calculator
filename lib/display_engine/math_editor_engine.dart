import 'math_nodes.dart';

/// Parent relationship metadata for a nested [MathContainerNode].
class ParentContainerRelation {
  final MathNode ownerNode;
  final MathContainerNode outerContainer;
  final int indexInOuterContainer;

  const ParentContainerRelation({
    required this.ownerNode,
    required this.outerContainer,
    required this.indexInOuterContainer,
  });
}

/// Spatial 2D Math AST Editor & Cursor Navigation Engine for the Cal_ 1100_DB_.
///
/// Manages the root [MathContainerNode], active cursor location
/// (`activeContainerId`, `childIndex`), 4-way spatial cursor movement
/// (`moveLeft`, `moveRight`, `moveUp`, `moveDown`), and smart 2D template
/// insertion and deletion.
class MathEditorEngine {
  MathContainerNode _root;
  String _activeContainerId;
  int _childIndex;

  MathEditorEngine({
    MathContainerNode? root,
    String? activeContainerId,
    int childIndex = 0,
  })  : _root = root ?? MathContainerNode(showEmptyPlaceholder: false),
        _activeContainerId = activeContainerId ?? '',
        _childIndex = childIndex + 0 {
    if (_activeContainerId.isEmpty) {
      _activeContainerId = _root.id;
    }
    _sanitizeCursor();
  }

  MathContainerNode get root => _root;
  String get activeContainerId => _activeContainerId;
  int get childIndex => _childIndex;

  bool get isEmpty => _root.children.isEmpty;

  /// Returns the currently focused [MathContainerNode] (falls back to [root]).
  MathContainerNode get activeContainer =>
      findContainerById(_activeContainerId) ?? _root;

  /// Deep-clones the entire editor state for immutable state snapshots / history.
  MathEditorEngine clone() {
    final clonedRoot = _clonePreservingIds(_root) as MathContainerNode;
    return MathEditorEngine(
      root: clonedRoot,
      activeContainerId: _activeContainerId,
      childIndex: _childIndex,
    );
  }

  MathNode _clonePreservingIds(MathNode node) {
    if (node is MathContainerNode) {
      return MathContainerNode(
        id: node.id,
        showEmptyPlaceholder: node.showEmptyPlaceholder,
        children: node.children.map(_clonePreservingIds).toList(),
      );
    }
    if (node is CharNode) {
      return CharNode(
        id: node.id,
        display: node.display,
        evalText: node.evalText,
      );
    }
    if (node is FractionNode) {
      return FractionNode(
        id: node.id,
        integerPart: node.integerPart != null
            ? _clonePreservingIds(node.integerPart!) as MathContainerNode
            : null,
        numerator: _clonePreservingIds(node.numerator) as MathContainerNode,
        denominator: _clonePreservingIds(node.denominator) as MathContainerNode,
      );
    }
    if (node is RadicalNode) {
      return RadicalNode(
        id: node.id,
        index: node.index != null
            ? _clonePreservingIds(node.index!) as MathContainerNode
            : null,
        radicand: _clonePreservingIds(node.radicand) as MathContainerNode,
      );
    }
    if (node is SuperscriptNode) {
      return SuperscriptNode(
        id: node.id,
        base: node.base != null
            ? _clonePreservingIds(node.base!) as MathContainerNode
            : null,
        exponent: _clonePreservingIds(node.exponent) as MathContainerNode,
      );
    }
    if (node is ParenthesisNode) {
      return ParenthesisNode(
        id: node.id,
        content: _clonePreservingIds(node.content) as MathContainerNode,
        isAbsoluteValue: node.isAbsoluteValue,
      );
    }
    if (node is LogBaseNode) {
      return LogBaseNode(
        id: node.id,
        base: _clonePreservingIds(node.base) as MathContainerNode,
        argument: _clonePreservingIds(node.argument) as MathContainerNode,
      );
    }
    if (node is IntegralNode) {
      return IntegralNode(
        id: node.id,
        lower: _clonePreservingIds(node.lower) as MathContainerNode,
        upper: _clonePreservingIds(node.upper) as MathContainerNode,
        body: _clonePreservingIds(node.body) as MathContainerNode,
      );
    }
    if (node is SummationNode) {
      return SummationNode(
        id: node.id,
        start: _clonePreservingIds(node.start) as MathContainerNode,
        end: _clonePreservingIds(node.end) as MathContainerNode,
        body: _clonePreservingIds(node.body) as MathContainerNode,
        isProduct: node.isProduct,
      );
    }
    if (node is DerivativeNode) {
      return DerivativeNode(
        id: node.id,
        body: _clonePreservingIds(node.body) as MathContainerNode,
        atValue: _clonePreservingIds(node.atValue) as MathContainerNode,
      );
    }
    return node.clone();
  }

  /// Resets the editor to an empty root container.
  void clear() {
    _root = MathContainerNode(showEmptyPlaceholder: false);
    _activeContainerId = _root.id;
    _childIndex = 0;
  }

  /// Replaces the root AST with a cloned tree and moves cursor to the end.
  void loadFromTree(MathContainerNode newRoot, {bool cursorAtEnd = true}) {
    _root = _clonePreservingIds(newRoot) as MathContainerNode;
    _activeContainerId = _root.id;
    _childIndex = cursorAtEnd ? _root.children.length : 0;
    _sanitizeCursor();
  }

  // ===========================================================================
  // Tree Lookup & Validation Helpers
  // ===========================================================================

  MathContainerNode? findContainerById(String targetId) {
    return _searchContainer(_root, targetId);
  }

  MathContainerNode? _searchContainer(
    MathContainerNode current,
    String targetId,
  ) {
    if (current.id == targetId) return current;
    for (final child in current.children) {
      for (final subContainer in child.childContainers) {
        final found = _searchContainer(subContainer, targetId);
        if (found != null) return found;
      }
    }
    return null;
  }

  ParentContainerRelation? findParentRelation(String targetContainerId) {
    return _searchParentRelation(_root, targetContainerId);
  }

  ParentContainerRelation? _searchParentRelation(
    MathContainerNode outer,
    String targetContainerId,
  ) {
    for (int i = 0; i < outer.children.length; i++) {
      final node = outer.children[i];
      for (final sub in node.childContainers) {
        if (sub.id == targetContainerId) {
          return ParentContainerRelation(
            ownerNode: node,
            outerContainer: outer,
            indexInOuterContainer: i,
          );
        }
        final deeper = _searchParentRelation(sub, targetContainerId);
        if (deeper != null) return deeper;
      }
    }
    return null;
  }

  void _sanitizeCursor() {
    final container = findContainerById(_activeContainerId);
    if (container == null) {
      _activeContainerId = _root.id;
      _childIndex = _root.children.length;
    } else {
      _childIndex = _childIndex.clamp(0, container.children.length);
    }
  }

  // ===========================================================================
  // Spatial 2D Cursor Navigation (Left, Right, Up, Down, Start, End)
  // ===========================================================================

  /// Moves cursor to the very start of the root expression.
  void moveToRootStart() {
    _activeContainerId = _root.id;
    _childIndex = 0;
  }

  /// Moves cursor to the very end of the root expression.
  void moveToRootEnd() {
    _activeContainerId = _root.id;
    _childIndex = _root.children.length;
  }

  /// Moves the cursor one logical step to the right, entering or exiting
  /// nested 2D containers seamlessly.
  void moveRight() {
    _sanitizeCursor();
    final container = activeContainer;

    if (_childIndex < container.children.length) {
      final nextNode = container.children[_childIndex];
      final subContainers = nextNode.childContainers;
      if (subContainers.isNotEmpty) {
        // Step inside the first child container of the composite 2D node
        _activeContainerId = subContainers.first.id;
        _childIndex = 0;
        return;
      }
      _childIndex += 1;
      return;
    }

    // At the right end of `container`: check if inside a parent 2D node
    final rel = findParentRelation(container.id);
    if (rel == null) {
      // At end of root container -> wrap around to start of root
      _activeContainerId = _root.id;
      _childIndex = 0;
      return;
    }

    final siblings = rel.ownerNode.childContainers;
    final int subIdx = siblings.indexWhere((c) => c.id == container.id);
    if (subIdx >= 0 && subIdx + 1 < siblings.length) {
      // Jump to start of next sibling container (e.g. numerator -> denominator)
      _activeContainerId = siblings[subIdx + 1].id;
      _childIndex = 0;
    } else {
      // Exit parent 2D node to the right in outer container
      _activeContainerId = rel.outerContainer.id;
      _childIndex = rel.indexInOuterContainer + 1;
    }
  }

  /// Moves the cursor one logical step to the left, entering or exiting
  /// nested 2D containers seamlessly.
  void moveLeft() {
    _sanitizeCursor();
    final container = activeContainer;

    if (_childIndex > 0) {
      final prevNode = container.children[_childIndex - 1];
      final subContainers = prevNode.childContainers;
      if (subContainers.isNotEmpty) {
        // Step inside the last child container at its right end
        final lastSub = subContainers.last;
        _activeContainerId = lastSub.id;
        _childIndex = lastSub.children.length;
        return;
      }
      _childIndex -= 1;
      return;
    }

    // At the left start of `container`: check if inside a parent 2D node
    final rel = findParentRelation(container.id);
    if (rel == null) {
      // At start of root container -> wrap around to end of root
      _activeContainerId = _root.id;
      _childIndex = _root.children.length;
      return;
    }

    final siblings = rel.ownerNode.childContainers;
    final int subIdx = siblings.indexWhere((c) => c.id == container.id);
    if (subIdx > 0) {
      // Jump to end of previous sibling container (e.g. denominator -> numerator)
      final prevSibling = siblings[subIdx - 1];
      _activeContainerId = prevSibling.id;
      _childIndex = prevSibling.children.length;
    } else {
      // Exit parent 2D node to the left in outer container
      _activeContainerId = rel.outerContainer.id;
      _childIndex = rel.indexInOuterContainer;
    }
  }

  /// Moves the cursor spatially downward (e.g. Numerator -> Denominator,
  /// Exponent -> Base, Integral Upper -> Body -> Lower).
  /// Returns `true` if a 2D vertical transition occurred, or `false` if at root.
  bool moveDown() {
    _sanitizeCursor();

    // 1. Check if the node immediately adjacent in the current container has a lower slot
    final curContainer = activeContainer;
    if (_childIndex > 0) {
      final leftNeighbor = curContainer.children[_childIndex - 1];
      if (leftNeighbor is LogBaseNode) {
        _activeContainerId = leftNeighbor.base.id;
        _childIndex = leftNeighbor.base.children.length;
        return true;
      }
      if (leftNeighbor is IntegralNode) {
        _activeContainerId = leftNeighbor.lower.id;
        _childIndex = leftNeighbor.lower.children.length;
        return true;
      }
      if (leftNeighbor is SummationNode) {
        _activeContainerId = leftNeighbor.start.id;
        _childIndex = leftNeighbor.start.children.length;
        return true;
      }
      if (leftNeighbor is DerivativeNode) {
        _activeContainerId = leftNeighbor.atValue.id;
        _childIndex = leftNeighbor.atValue.children.length;
        return true;
      }
    }

    // 2. Walk up ancestor chain looking for a vertical downward transition
    String probeId = _activeContainerId;
    int probeIndex = _childIndex;

    while (true) {
      final rel = findParentRelation(probeId);
      if (rel == null) break;

      final owner = rel.ownerNode;
      if (owner is FractionNode) {
        if (probeId == owner.numerator.id) {
          _activeContainerId = owner.denominator.id;
          _childIndex = _mapProportionalSlot(
            owner.numerator,
            probeIndex,
            owner.denominator,
          );
          return true;
        }
        if (owner.integerPart != null && probeId == owner.integerPart!.id) {
          _activeContainerId = owner.denominator.id;
          _childIndex = 0;
          return true;
        }
      } else if (owner is SuperscriptNode) {
        if (probeId == owner.exponent.id) {
          if (owner.base != null) {
            _activeContainerId = owner.base!.id;
            _childIndex = owner.base!.children.length;
          } else {
            _activeContainerId = rel.outerContainer.id;
            _childIndex = rel.indexInOuterContainer + 1;
          }
          return true;
        }
      } else if (owner is RadicalNode) {
        if (owner.index != null && probeId == owner.index!.id) {
          _activeContainerId = owner.radicand.id;
          _childIndex = 0;
          return true;
        }
      } else if (owner is LogBaseNode) {
        if (probeId == owner.argument.id) {
          _activeContainerId = owner.base.id;
          _childIndex = owner.base.children.length;
          return true;
        }
      } else if (owner is IntegralNode) {
        if (probeId == owner.upper.id) {
          _activeContainerId = owner.lower.id;
          _childIndex = owner.lower.children.length;
          return true;
        }
        if (probeId == owner.body.id) {
          _activeContainerId = owner.lower.id;
          _childIndex = owner.lower.children.length;
          return true;
        }
      } else if (owner is SummationNode) {
        if (probeId == owner.end.id) {
          _activeContainerId = owner.start.id;
          _childIndex = owner.start.children.length;
          return true;
        }
        if (probeId == owner.body.id) {
          _activeContainerId = owner.start.id;
          _childIndex = owner.start.children.length;
          return true;
        }
      } else if (owner is DerivativeNode) {
        if (probeId == owner.body.id) {
          _activeContainerId = owner.atValue.id;
          _childIndex = owner.atValue.children.length;
          return true;
        }
      }

      probeId = rel.outerContainer.id;
      probeIndex = rel.indexInOuterContainer;
    }

    return false;
  }

  /// Moves the cursor spatially upward (e.g. Denominator -> Numerator,
  /// Base -> Exponent, Subscript -> Argument, Integral Lower -> Upper).
  /// Returns `true` if a 2D vertical transition occurred, or `false` if at root.
  bool moveUp() {
    _sanitizeCursor();

    // 1. If immediately to the right of a SuperscriptNode, IntegralNode, or SummationNode, jump into upper slot
    final curContainer = activeContainer;
    if (_childIndex > 0) {
      final leftNeighbor = curContainer.children[_childIndex - 1];
      if (leftNeighbor is SuperscriptNode) {
        _activeContainerId = leftNeighbor.exponent.id;
        _childIndex = leftNeighbor.exponent.children.length;
        return true;
      }
      if (leftNeighbor is IntegralNode) {
        _activeContainerId = leftNeighbor.upper.id;
        _childIndex = leftNeighbor.upper.children.length;
        return true;
      }
      if (leftNeighbor is SummationNode) {
        _activeContainerId = leftNeighbor.end.id;
        _childIndex = leftNeighbor.end.children.length;
        return true;
      }
    }

    // 2. Walk up ancestor chain looking for a vertical upward transition
    String probeId = _activeContainerId;
    int probeIndex = _childIndex;

    while (true) {
      final rel = findParentRelation(probeId);
      if (rel == null) break;

      final owner = rel.ownerNode;
      if (owner is FractionNode) {
        if (probeId == owner.denominator.id) {
          _activeContainerId = owner.numerator.id;
          _childIndex = _mapProportionalSlot(
            owner.denominator,
            probeIndex,
            owner.numerator,
          );
          return true;
        }
      } else if (owner is SuperscriptNode) {
        if (owner.base != null && probeId == owner.base!.id) {
          _activeContainerId = owner.exponent.id;
          _childIndex = 0;
          return true;
        }
      } else if (owner is RadicalNode) {
        if (owner.index != null && probeId == owner.radicand.id) {
          _activeContainerId = owner.index!.id;
          _childIndex = owner.index!.children.length;
          return true;
        }
      } else if (owner is LogBaseNode) {
        if (probeId == owner.base.id) {
          _activeContainerId = owner.argument.id;
          _childIndex = 0;
          return true;
        }
      } else if (owner is IntegralNode) {
        if (probeId == owner.lower.id) {
          _activeContainerId = owner.upper.id;
          _childIndex = owner.upper.children.length;
          return true;
        }
        if (probeId == owner.body.id) {
          _activeContainerId = owner.upper.id;
          _childIndex = owner.upper.children.length;
          return true;
        }
      } else if (owner is SummationNode) {
        if (probeId == owner.start.id) {
          _activeContainerId = owner.end.id;
          _childIndex = owner.end.children.length;
          return true;
        }
        if (probeId == owner.body.id) {
          _activeContainerId = owner.end.id;
          _childIndex = owner.end.children.length;
          return true;
        }
      } else if (owner is DerivativeNode) {
        if (probeId == owner.atValue.id) {
          _activeContainerId = owner.body.id;
          _childIndex = owner.body.children.length;
          return true;
        }
      }

      probeId = rel.outerContainer.id;
      probeIndex = rel.indexInOuterContainer;
    }

    return false;
  }

  int _mapProportionalSlot(
    MathContainerNode source,
    int sourceIndex,
    MathContainerNode target,
  ) {
    if (target.children.isEmpty) return 0;
    if (source.children.isEmpty) {
      return (target.children.length / 2).round();
    }
    final double ratio = sourceIndex / source.children.length;
    return (ratio * target.children.length)
        .round()
        .clamp(0, target.children.length);
  }

  // ===========================================================================
  // Editing Operations (Insert & Backspace / DEL)
  // ===========================================================================

  /// Inserts a [CharNode] (or any [MathNode]) at the current cursor slot.
  void insertNode(MathNode node, {bool isInsertMode = true}) {
    _sanitizeCursor();
    final container = activeContainer;

    if (!isInsertMode && _childIndex < container.children.length) {
      container.children[_childIndex] = node;
      _childIndex += 1;
    } else {
      container.children.insert(_childIndex, node);
      _childIndex += 1;
    }
  }

  /// Inserts an atomic character/operator/variable token.
  void insertChar(
    String display, {
    String? evalText,
    bool isInsertMode = true,
  }) {
    insertNode(
      CharNode(display: display, evalText: evalText),
      isInsertMode: isInsertMode,
    );
  }

  /// Inserts a 2D [FractionNode].
  ///
  /// Implements Cal_'s Natural Textbook wrapping rule: if [mixed] is false and
  /// there is a contiguous operand immediately preceding the cursor in the
  /// active container, those operand nodes are automatically wrapped into the
  /// fraction's numerator and the cursor is placed in the denominator!
  void insertFraction({bool mixed = false}) {
    _sanitizeCursor();
    final container = activeContainer;

    if (mixed) {
      final frac = FractionNode(
        integerPart: MathContainerNode(),
        numerator: MathContainerNode(),
        denominator: MathContainerNode(),
      );
      container.children.insert(_childIndex, frac);
      _activeContainerId = frac.integerPart!.id;
      _childIndex = 0;
      return;
    }

    // Collect preceding contiguous operand nodes (e.g. digits, variables, parens)
    int wrapStart = _childIndex;
    while (wrapStart > 0) {
      final candidate = container.children[wrapStart - 1];
      if (candidate is CharNode && candidate.isOperandToken) {
        wrapStart -= 1;
      } else if (candidate is ParenthesisNode ||
          candidate is RadicalNode ||
          candidate is SuperscriptNode) {
        wrapStart -= 1;
        break;
      } else {
        break;
      }
    }

    if (wrapStart < _childIndex) {
      final wrappedNodes = container.children.sublist(wrapStart, _childIndex);
      container.children.removeRange(wrapStart, _childIndex);
      final frac = FractionNode(
        numerator: MathContainerNode(children: wrappedNodes),
        denominator: MathContainerNode(),
      );
      container.children.insert(wrapStart, frac);
      _activeContainerId = frac.denominator.id;
      _childIndex = 0;
    } else {
      final frac = FractionNode();
      container.children.insert(_childIndex, frac);
      _activeContainerId = frac.numerator.id;
      _childIndex = 0;
    }
  }

  /// Inserts a 2D [RadicalNode] ($\sqrt{\square}$ or $\sqrt[\square]{\square}$).
  void insertRadical({bool nthRoot = false}) {
    _sanitizeCursor();
    final container = activeContainer;
    final radical = RadicalNode(
      index: nthRoot ? MathContainerNode() : null,
      radicand: MathContainerNode(),
    );
    container.children.insert(_childIndex, radical);
    if (nthRoot) {
      _activeContainerId = radical.index!.id;
      _childIndex = 0;
    } else {
      _activeContainerId = radical.radicand.id;
      _childIndex = 0;
    }
  }

  /// Inserts a 2D [SuperscriptNode] ($x^\square$, $x^2$, $x^{-1}$, $10^\square$, $e^\square$).
  void insertSuperscript({
    List<MathNode>? initialBase,
    List<MathNode>? initialExponent,
    bool focusExponent = true,
  }) {
    _sanitizeCursor();
    final container = activeContainer;

    if (initialBase != null) {
      final sup = SuperscriptNode(
        base: MathContainerNode(children: initialBase),
        exponent: MathContainerNode(children: initialExponent ?? []),
      );
      container.children.insert(_childIndex, sup);
      if (focusExponent) {
        _activeContainerId = sup.exponent.id;
        _childIndex = sup.exponent.children.length;
      } else {
        _childIndex += 1;
      }
      return;
    }

    // Check if there is a preceding operand token to attach the superscript to
    final bool hasPrecedingOperand = _childIndex > 0 &&
        ((container.children[_childIndex - 1] is CharNode &&
                (container.children[_childIndex - 1] as CharNode)
                    .isOperandToken) ||
            container.children[_childIndex - 1] is ParenthesisNode ||
            container.children[_childIndex - 1] is RadicalNode ||
            container.children[_childIndex - 1] is FractionNode);

    final sup = SuperscriptNode(
      base: hasPrecedingOperand ? null : MathContainerNode(),
      exponent: MathContainerNode(children: initialExponent ?? []),
    );
    container.children.insert(_childIndex, sup);

    if (!hasPrecedingOperand && sup.base != null) {
      _activeContainerId = sup.base!.id;
      _childIndex = 0;
    } else if (focusExponent) {
      _activeContainerId = sup.exponent.id;
      _childIndex = sup.exponent.children.length;
    } else {
      _childIndex += 1;
    }
  }

  /// Inserts a 2D auto-sizing [ParenthesisNode] or absolute value `|□|`.
  void insertParenthesis({bool isAbsoluteValue = false}) {
    _sanitizeCursor();
    final container = activeContainer;
    final paren = ParenthesisNode(isAbsoluteValue: isAbsoluteValue);
    container.children.insert(_childIndex, paren);
    _activeContainerId = paren.content.id;
    _childIndex = 0;
  }

  /// Inserts a 2D arbitrary-base logarithm $\log_\blacksquare(\square)$.
  void insertLogBase() {
    _sanitizeCursor();
    final container = activeContainer;
    final logNode = LogBaseNode();
    container.children.insert(_childIndex, logNode);
    _activeContainerId = logNode.base.id;
    _childIndex = 0;
  }

  /// Inserts a 2D definite integral $\int_\square^\square (\blacksquare)\,dx$.
  void insertIntegral() {
    _sanitizeCursor();
    final container = activeContainer;
    final intNode = IntegralNode();
    container.children.insert(_childIndex, intNode);
    _activeContainerId = intNode.body.id;
    _childIndex = 0;
  }

  /// Inserts a 2D discrete summation $\sum_{x=\square}^\square (\blacksquare)$
  /// or product $\prod_{x=\square}^\square (\blacksquare)$.
  void insertSummation({bool isProduct = false}) {
    _sanitizeCursor();
    final container = activeContainer;
    final sumNode = SummationNode(isProduct: isProduct);
    container.children.insert(_childIndex, sumNode);
    _activeContainerId = sumNode.body.id;
    _childIndex = 0;
  }

  /// Inserts a 2D numerical derivative $\left.\frac{d}{dx}(\blacksquare)\right|_{x=\square}$.
  void insertDerivative() {
    _sanitizeCursor();
    final container = activeContainer;
    final derivNode = DerivativeNode();
    container.children.insert(_childIndex, derivNode);
    _activeContainerId = derivNode.body.id;
    _childIndex = 0;
  }

  /// Deletes the node/structure before the cursor (`⌫` / `DEL`) with full
  /// structural unwrapping and zero crashes on empty nested boxes.
  void deleteBackward({bool isInsertMode = true}) {
    _sanitizeCursor();
    final container = activeContainer;

    if (!isInsertMode && _childIndex < container.children.length) {
      container.children.removeAt(_childIndex);
      return;
    }

    if (_childIndex > 0) {
      final target = container.children[_childIndex - 1];
      final subContainers = target.childContainers;

      if (subContainers.isEmpty) {
        // Simple CharNode: delete directly
        container.children.removeAt(_childIndex - 1);
        _childIndex -= 1;
        return;
      }

      // Composite 2D node: if all child containers are empty, remove the whole node;
      // otherwise step inside its last child container so user can edit inside it.
      final bool allEmpty = subContainers.every((c) => c.isEmpty);
      if (allEmpty) {
        container.children.removeAt(_childIndex - 1);
        _childIndex -= 1;
      } else {
        final lastSub = subContainers.last;
        _activeContainerId = lastSub.id;
        _childIndex = lastSub.children.length;
      }
      return;
    }

    // `_childIndex == 0`: Cursor is at the very beginning of `container`.
    final rel = findParentRelation(container.id);
    if (rel == null) {
      // At root start: nothing before cursor
      return;
    }

    final owner = rel.ownerNode;
    final outer = rel.outerContainer;
    final int ownerIdx = rel.indexInOuterContainer;
    final allSubEmpty = owner.childContainers.every((c) => c.isEmpty);

    if (allSubEmpty) {
      // Dissolve completely empty 2D template and restore flat cursor in outer container
      outer.children.removeAt(ownerIdx);
      _activeContainerId = outer.id;
      _childIndex = ownerIdx;
      return;
    }

    if (owner is FractionNode) {
      if (container.id == owner.denominator.id && owner.denominator.isEmpty) {
        // Dissolve fraction bar and unwrap numerator nodes into outer container
        final preserved = List<MathNode>.from(owner.numerator.children);
        outer.children.removeAt(ownerIdx);
        outer.children.insertAll(ownerIdx, preserved);
        _activeContainerId = outer.id;
        _childIndex = ownerIdx + preserved.length;
        return;
      }
      if (container.id == owner.numerator.id && owner.numerator.isEmpty) {
        // Unwrap denominator nodes into outer container
        final preserved = List<MathNode>.from(owner.denominator.children);
        outer.children.removeAt(ownerIdx);
        outer.children.insertAll(ownerIdx, preserved);
        _activeContainerId = outer.id;
        _childIndex = ownerIdx;
        return;
      }
    }

    if (owner is RadicalNode && container.id == owner.radicand.id) {
      if (owner.index == null || owner.index!.isEmpty) {
        // Unwrap radicand children into outer container
        final preserved = List<MathNode>.from(owner.radicand.children);
        outer.children.removeAt(ownerIdx);
        outer.children.insertAll(ownerIdx, preserved);
        _activeContainerId = outer.id;
        _childIndex = ownerIdx;
        return;
      }
    }

    if (owner is ParenthesisNode && container.id == owner.content.id) {
      // Unwrap parenthesized content into outer container
      final preserved = List<MathNode>.from(owner.content.children);
      outer.children.removeAt(ownerIdx);
      outer.children.insertAll(ownerIdx, preserved);
      _activeContainerId = outer.id;
      _childIndex = ownerIdx;
      return;
    }

    if (owner is SuperscriptNode && container.id == owner.exponent.id) {
      if (owner.exponent.isEmpty) {
        final preserved = owner.base != null
            ? List<MathNode>.from(owner.base!.children)
            : <MathNode>[];
        outer.children.removeAt(ownerIdx);
        outer.children.insertAll(ownerIdx, preserved);
        _activeContainerId = outer.id;
        _childIndex = ownerIdx + preserved.length;
        return;
      }
    }

    // Default fallback when at index 0 of a populated sub-container: step left
    moveLeft();
  }
}
