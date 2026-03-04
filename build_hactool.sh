#!/data/data/com.termux/files/usr/bin/bash
# =============================================================
# hactool Termux Build Script
# Drop this file into your hactool-master/ folder and run it.
# =============================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
die()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Make sure we're in the right place
[ -f "Makefile" ] && [ -f "main.c" ] || die "Run this script from inside the hactool-master/ directory."

# ---------------------------------------------------------------
# 1. Install dependencies (clang + make only — uses bundled mbedtls)
# ---------------------------------------------------------------
info "Installing build tools..."
pkg install -y clang make 2>/dev/null || die "pkg install failed. Run: pkg update"

# ---------------------------------------------------------------
# 2. Create config.mk  (THE main reason it fails — file is missing)
# ---------------------------------------------------------------
info "Creating config.mk..."
cat > config.mk << 'EOF'
CC     = clang
CFLAGS = -O2 -Wall -std=gnu11 -fPIC
LDFLAGS = -lmbedtls -lmbedx509 -lmbedcrypto
EOF
info "config.mk written."

# ---------------------------------------------------------------
# 3. Fix the fseeko64 → fseeko conflict on Android/Bionic
#
#    utils.h defines:  #define fseeko64 fseek
#    But with -D_FILE_OFFSET_BITS=64 the Makefile already makes
#    fseek() 64-bit, so this is fine. However Bionic's fseeko()
#    is already 64-bit too and some Clang versions complain about
#    the double macro. Safest fix: redefine it as fseeko.
# ---------------------------------------------------------------
info "Patching utils.h fseeko64 macro for Android..."
sed -i 's/#define fseeko64 fseek/#define fseeko64 fseeko/' utils.h
# (idempotent — running twice is harmless)

# ---------------------------------------------------------------
# 4. Build bundled mbedtls 2.6.1 first
# ---------------------------------------------------------------
info "Building bundled mbedtls 2.6.1..."
make -C mbedtls lib -j$(nproc) 2>&1 | tail -5

# ---------------------------------------------------------------
# 5. Build hactool
# ---------------------------------------------------------------
info "Building hactool..."
make hactool -j$(nproc)

# ---------------------------------------------------------------
# 6. Install
# ---------------------------------------------------------------
info "Installing hactool to \$PREFIX/bin..."
cp hactool "$PREFIX/bin/hactool"
chmod 755 "$PREFIX/bin/hactool"

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Build complete! hactool is ready.${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "USAGE:"
echo "  hactool -t nca  yourfile.nca"
echo "  hactool -t xci  yourgame.xci"
echo "  hactool -t nsp  yourgame.nsp"
echo "  hactool -t save yoursave"
echo ""
echo "KEYS FILE:"
echo "  Place your prod.keys at:  ~/.switch/prod.keys"
echo "  (hactool checks there automatically)"
echo ""
echo "ACCESSING FILES ON YOUR SD CARD / INTERNAL STORAGE:"
echo "  Run this ONCE to grant Termux storage access:"
echo "    termux-setup-storage"
echo "  Then your storage is at: ~/storage/shared/"
echo "  Example:"
echo "    hactool -t nca ~/storage/shared/Download/game.nca"

