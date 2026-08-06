#!/usr/bin/env bash

set -euo pipefail

# 1. installation pre-config
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
SUPERBUILD_DIR="$(dirname "${PROJECT_DIR}")"
SRC_DIR="${SUPERBUILD_DIR}/src"
INSTALL_DIR="${SUPERBUILD_DIR}/install"
PRESET="${SETUP_PRESET:-G1-notests}"

UNITREE_SDK2_REPO="https://github.com/y-hadj/unitree_sdk2.git"
UNITREE_SDK2_DIR="${SRC_DIR}/unitree_sdk2"

log() { printf '\n== %s\n' "$*"; }
die() { printf '\n!! %s\n' "$*" >&2; exit 1; }


detect_mem_mib() {
  local total limit cg
  total="$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)"
  for cg in /sys/fs/cgroup/memory.max /sys/fs/cgroup/memory/memory.limit_in_bytes; do
    [[ -r "${cg}" ]] || continue
    read -r limit < "${cg}" || continue
    # "max" (v2, uncapped) or an astronomically large sentinel (v1)
    [[ "${limit}" =~ ^[0-9]+$ ]] || continue
    limit=$(( limit / 1048576 ))
    (( limit > 0 && limit < total )) && total="${limit}"
  done
  printf '%s' "${total}"
}


detect_cores() {
  local cores quota period
  cores="$(nproc)"
  if [[ -r /sys/fs/cgroup/cpu.max ]]; then
    read -r quota period < /sys/fs/cgroup/cpu.max || true
    if [[ "${quota:-max}" =~ ^[0-9]+$ && "${period:-0}" =~ ^[1-9][0-9]*$ ]]; then
      quota=$(( quota / period ))
      (( quota > 0 && quota < cores )) && cores="${quota}"
    fi
  fi
  printf '%s' "${cores}"
}

detect_jobs() {
  local cores mem_mib mem_jobs jobs
  cores="$(detect_cores)"
  mem_mib="$(detect_mem_mib)"
  # reserve 2 GiB for the editor/language servers, budget 1.8 GiB per job
  mem_jobs=$(( (mem_mib - 2048) / 1800 ))
  jobs=$(( cores > 2 ? cores - 2 : 1 ))
  (( mem_jobs < jobs )) && jobs="${mem_jobs}"
  (( jobs < 1 )) && jobs=1
  printf '%s' "${jobs}"
}

JOBS="${SETUP_JOBS:-$(detect_jobs)}"


if [[ "${UID}" -eq 0 ]]; then
  SUDO=''
else
  SUDO='sudo'
  command -v sudo > /dev/null || die "sudo not found but required to bootstrap"
fi
command -v apt-get > /dev/null \
  || die "apt-get not found but required to bootstrap, are you using a Debian-based distribution?"

echo "superbuild : ${SUPERBUILD_DIR}"
echo "preset     : ${PRESET}"
echo "jobs       : ${JOBS}"


if [[ "${UID}" -ne 0 ]] && find "${INSTALL_DIR}" ! -user "$(id -un)" -print -quit 2>/dev/null | grep -q .; then
  log "fixing ownership of ${INSTALL_DIR}"
  ${SUDO} chown -R "$(id -un):$(id -gn)" "${INSTALL_DIR}"
fi


export ROS_PARALLEL_JOBS="-j${JOBS} -l${JOBS}"


cd "${PROJECT_DIR}"

configure_superbuild() {
  local with_g1="$1"
  cmake --preset="${PRESET}" \
    -DWITH_G1="${with_g1}" \
    -DBUILD_PARALLEL_JOBS="${JOBS}"
  # The preset also sets WITH_G1; make sure our override actually landed.
  grep -qx "WITH_G1:BOOL=${with_g1}" "${PROJECT_DIR}/build/CMakeCache.txt" \
    || die "failed to set WITH_G1=${with_g1} in ${PROJECT_DIR}/build/CMakeCache.txt"
}


# 2. bootstrap and build mc-rtc-superbuild
log "[1/3] setting up mc-rtc-superbuild..."

bash "${SCRIPT_DIR}/bootstrap-linux.sh"

configure_superbuild OFF
cmake --build --preset="${PRESET}"

[[ -f "${INSTALL_DIR}/setup_mc_rtc.sh" ]] \
  || die "${INSTALL_DIR}/setup_mc_rtc.sh not found: step 1 did not install successfully"


if grep -q 'setup\.zsh\|local_setup\.zsh' "${INSTALL_DIR}/setup_mc_rtc.sh" && [[ -z "${ZSH_VERSION:-}" ]]; then
  echo "note: setup_mc_rtc.sh targets zsh, not sourcing it in this bash run"
else
  set +u # the generated env script is not -u clean
  source "${INSTALL_DIR}/setup_mc_rtc.sh" || echo "warning: could not source setup_mc_rtc.sh"
  set -u
fi

# source mc-rtc-superbuild
for rc_file in "${HOME}/.zshrc" "${HOME}/.bashrc"; do
  [[ -f "${rc_file}" ]] || continue
  grep -q "setup_mc_rtc.sh" "${rc_file}" && continue
  echo "[ -f \"${INSTALL_DIR}/setup_mc_rtc.sh\" ] && source \"${INSTALL_DIR}/setup_mc_rtc.sh\"" >> "${rc_file}"
done


# 3. unitree_sdk2
log "[2/3] setting up unitree_sdk2..."

${SUDO} apt-get update
${SUDO} apt-get install -y cmake g++ build-essential libyaml-cpp-dev \
  libeigen3-dev libboost-all-dev libspdlog-dev libfmt-dev

mkdir -p "${SRC_DIR}"
if [[ -d "${UNITREE_SDK2_DIR}/.git" ]]; then
  echo "${UNITREE_SDK2_DIR} already cloned, fetching updates"
  git -C "${UNITREE_SDK2_DIR}" pull --ff-only || echo "warning: could not fast-forward, keeping local state"
else
  [[ -e "${UNITREE_SDK2_DIR}" ]] && die "${UNITREE_SDK2_DIR} exists but is not a git clone, remove it and re-run"
  git clone "${UNITREE_SDK2_REPO}" "${UNITREE_SDK2_DIR}"
fi

cmake -S "${UNITREE_SDK2_DIR}" -B "${UNITREE_SDK2_DIR}/build" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}"
# Installs into the user-owned prefix: no sudo, otherwise the superbuild can no
# longer write to install/ afterwards.
cmake --build "${UNITREE_SDK2_DIR}/build" --parallel "${JOBS}" --target install


# 4. mc_unitree 
log "[3/3] setting up mc_unitree..."

configure_superbuild ON
cmake --build --preset="${PRESET}"

# cat <<EOF
# ------------------------------------------------------------
# Successfully installed all dependencies. Verify with:
#     ls ${INSTALL_DIR}/bin/ | grep MCControl
# Open a new shell (or 'source ${INSTALL_DIR}/setup_mc_rtc.sh')
# to get the environment.
# ------------------------------------------------------------
# EOF
