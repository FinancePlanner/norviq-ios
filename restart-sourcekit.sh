#!/bin/bash

echo "🔄 Restarting SourceKit-LSP..."

# Kill any running SourceKit-LSP processes
pkill -f sourcekit-lsp

echo "✅ SourceKit-LSP restarted. Xcode should now see new files."
