#!/usr/bin/env bash

BASE_DIR=${BASE_DIR:="$HOME/Aria-MobileSim"}
ARIA_TAR_URL=${ARIA_TAR_URL:="http://robots.mobilerobots.com/ARIA/download/current/ARIA-src-2.9.4.tar.gz"}
MOBILESIM_TAR_URL=${MOBILESIM_TAR_URL:="http://robots.mobilerobots.com/MobileSim/download/current/MobileSim-src-0.9.8.tar.gz"}
ARIA_TAR=${ARIA_TAR:="${BASE_DIR}/ARIA-src-2.9.4.tar.gz"}
MOBILESIM_TAR=${MOBILESIM_TAR:="${BASE_DIR}/MobileSim-src-0.9.8.tar.gz"}
ARIA_EXTRACT_DIR="$BASE_DIR/$(basename "$ARIA_TAR" .tar.gz)"
MOBILESIM_EXTRACT_DIR="$BASE_DIR/$(basename "$MOBILESIM_TAR" .tar.gz)"

log() {
  local log_text="$1"
  local log_level="$2"
  local log_color="$3"

    # Default level to "info"
    [[ -z ${log_level} ]] && log_level="INFO";
    [[ -z ${log_color} ]] && log_color="${LOG_INFO_COLOR}";

    echo -e "${log_color}[$(date +"%Y-%m-%d %H:%M:%S %Z")] [${log_level}] ${log_text} ${LOG_DEFAULT_COLOR}";
    return 0
  }

log_info()      { log "$@"; }
log_success()   { log "$1" "SUCCESS"; }
log_error()     { log "$1" "ERROR"; }
log_warning()   { log "$1" "WARNING"; }
log_debug()     { log "$1" "DEBUG"; }

print_error_and_exit() {
  local errcode=$?
  log_error "An error occurred, last function/command exited with non-zero status"
  log_error "${FUNCNAME[$i]} was called from the file ${BASH_SOURCE[$i+1]} at line number ${BASH_LINENO[$i]}"
  exit $errcode
}

download_and_untar() {
  local errcode=0
  mkdir -p "$BASE_DIR"
  cd "$BASE_DIR" || { log_error "Failed to change directory to $BASE_DIR"; return 1; }

  [ -e "$ARIA_TAR" ] || wget http://robots.mobilerobots.com/ARIA/download/current/ARIA-src-2.9.4.tar.gz -O "$ARIA_TAR"
  [ -e "$MOBILESIM_TAR" ] || wget http://robots.mobilerobots.com/MobileSim/download/current/MobileSim-src-0.9.8.tar.gz -O "$MOBILESIM_TAR"

  tar -zxvpf "$ARIA_TAR" -C "$BASE_DIR" || errcode=1
  tar -zxvpf "$MOBILESIM_TAR" -C "$BASE_DIR" || errcode=1

  return $errcode
}

install_xcode_command_line_tools() {
  xcode-select --install
}

fix_weird_error() {
  sed -i '' 's/if(myOldJoyDesc > 0)/if(myOldJoyDesc > (void *)0)/' "$ARIA_EXTRACT_DIR/src/ArJoyHandler_LIN.cpp"
}

install_homebrew() {
  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
}

install_autoconf_and_automake() {
  if install_homebrew; then
    brew install autoconf automake
  fi
}

install_gtk() {
  install_autoconf_and_automake
  brew install gtk+
  # mkdir -p $HOME/gtk/inst/bin
  # cp -p /usr/local/Cellar/automake/**/bin/* $HOME/gtk/inst/bin
  # cp -p /usr/local/Cellar/autoconf/**/bin/* $HOME/gtk/inst/bin
  # export PATH=$HOME/.local/bin:$PATH
  # curl -s https://gitlab.gnome.org/GNOME/gtk-osx/raw/master/gtk-osx-build-setup.sh | bash
  # jhbuild bootstrap
  # jhbuild build python meta-gtk-osx-bootstrap meta-gtk-osx-core
}

build() {
  local extract_dir
  extract_dir="$1"
  if cd "$extract_dir";then
    make all || return 1
    return 0
  fi
}

build_aria() {
  fix_weird_error
  build "$ARIA_EXTRACT_DIR" || return 1
}

build_mobilesim() {
  install_gtk
  build "$MOBILESIM_EXTRACT_DIR" || return 1
}

update_bashrc() {

  cat >> "$BASE_DIR/.bashrc" <<EOF
export ARIA=$ARIA_EXTRACT_DIR
export MOBILESIM=$MOBILESIM_EXTRACT_DIR
export GTK_DIR=/usr/local/Cellar/gtk+/2.24.32_2
# export LDFLAGS="-L/usr/local/opt/libffi/lib"
export DYLD_LIBRARY_PATH=/usr/local/lib:$ARIA_EXTRACT_DIR/lib:$GTK_DIR/lib
export PKG_CONFIG_PATH=/usr/local/opt/libffi/lib/pkgconfig:/usr/local/Cellar/gtk+/2.24.32_2/lib/pkgconfig
export PATH=/usr/local/Cellar/gtk+/2.24.32_2/bin:$PATH
EOF
  local diff=$(comm -13 <(sort "$HOME/.bashrc") <(sort "$BASE_DIR/.bashrc"))
  if [[ "$diff" != "" ]]; then
    if [[ $DRYRUN != "true" ]];then
      cat "$diff" >> "$HOME/.bashrc"
      echo 'if [ -f ~/.bashrc ]; then . ~/.bashrc; fi' >> "$HOME/.bash_profile"
    fi
  fi

}

run() {
  download_and_untar
  install_xcode_command_line_tools
  update_bashrc
  source "$HOME/.bashrc"
  build_aria
  build_mobilesim
}

run "$@"
