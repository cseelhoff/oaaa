# VS Code Extension for Odin Small Array Shorthand

## Goal
Create a VS Code extension that lets you write `enemies[player]` in the editor, but automatically saves it as `sa.slice(&mm.enemies[gc.cur_player])`.

## Approach: Text Document Content Provider + Decorations

### Strategy 1: Virtual Document (Complex but Clean)
Use VS Code's virtual document system:
- Show a "virtual" version of the file with shorthand syntax
- When editing, translate shorthand → full syntax before saving
- **Pros**: Clean separation, true shorthand editing
- **Cons**: Complex to implement, may confuse version control

### Strategy 2: Decorations + Snippet Expansion (Recommended)
Use decorations to visually hide verbose parts:
- Display: Hide `sa.slice(&` and trailing `)`
- Typing: Use snippets/autocomplete to expand shorthand
- **Pros**: Simpler, file always has correct syntax
- **Cons**: Visual-only simplification

### Strategy 3: Code Actions (Hybrid)
Provide code actions to toggle between forms:
- Right-click → "Expand to full small_array syntax"
- Right-click → "Collapse to shorthand"
- **Pros**: Explicit, easy to understand
- **Cons**: Manual toggling required

## Recommended Implementation: Strategy 2 + 3 Combined

### Phase 1: Visual Simplification (Decorations)
```typescript
// Find pattern: sa.slice(&something)
const pattern = /sa\.slice\(&([^)]+)\)/g;

// Apply decoration to hide "sa.slice(&" and ")"
const decoration = vscode.window.createTextEditorDecorationType({
    opacity: '0',  // Make it invisible
    letterSpacing: '-1000px'  // Collapse the space
});
```

### Phase 2: Smart Typing (Snippets)
Create snippets that expand shorthand:
```json
{
    "small_array_slice": {
        "prefix": ["enemies[", "allies["],
        "body": "sa.slice(&mm.${1:array}[$2])",
        "description": "Small array slice shorthand"
    }
}
```

### Phase 3: Code Actions (Toggle)
Provide quick actions:
- "Expand small_array shortcuts" - remove decorations temporarily
- "Collapse small_array verbose syntax" - reapply decorations

## File Structure
```
odin-smallarray-shorthand/
├── package.json          # Extension manifest
├── src/
│   ├── extension.ts      # Main activation
│   ├── decorator.ts      # Handle visual hiding
│   ├── snippets.ts       # Smart expansion
│   └── codeActions.ts    # Toggle commands
├── snippets/
│   └── odin.json         # Snippet definitions
└── README.md
```

## Key VS Code APIs to Use
1. `vscode.window.createTextEditorDecorationType()` - Hide verbose syntax
2. `vscode.languages.registerCompletionItemProvider()` - Smart autocomplete
3. `vscode.languages.registerCodeActionsProvider()` - Toggle actions
4. `vscode.workspace.onDidChangeTextDocument()` - Track changes
5. `vscode.window.onDidChangeActiveTextEditor()` - Update decorations

## Alternative: Simpler Approach
If the above is too complex, start with just **snippets**:
1. Type `sas` → expands to `sa.slice(&$1)`
2. Type `enemies[` → triggers completion → expands to `sa.slice(&mm.enemies[gc.cur_player])`

This gives you fast typing without any decoration complexity.

## Next Steps
1. Would you like me to generate the full extension code?
2. Which strategy do you prefer?
3. Should we start simple (snippets only) or go full featured?
