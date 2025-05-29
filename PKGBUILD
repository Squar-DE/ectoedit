# Maintainer: SquarDE <spikygames123@gmail.com>
pkgname=ectoedit
pkgver=1.0.0
pkgrel=1
pkgdesc="A sleek text editor with syntax highlighting and LibAdwaita"
arch=('x86_64')
url="https://github.com/Squar-DE/ectoedit"
license=('GPL3')
depends=('gtk4' 'libadwaita' 'gtksourceview5')
source=("$pkgname-$pkgver.tar.xz::https://github.com/Squar-DE/ectoedit/releases/download/v$pkgver/ectoedit-v$pkgver.tar.xz")
sha256sums=('SKIP')

package() {
  cd "$srcdir/$pkgname-v$pkgver"
  # Binary
  install -Dm755 ectoedit "$pkgdir/usr/bin/ectoedit"
  # Desktop Entry
  install -Dm644 ectoedit.desktop "$pkgdir/usr/share/applications/ectoedit.desktop"
  install -Dm644 icons/EctoEdit.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/ectoedit.svg"
}
