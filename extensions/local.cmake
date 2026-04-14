set(EXTENSIONS_DIR ${CMAKE_CURRENT_LIST_DIR}/superbuild-extensions)
include(${EXTENSIONS_DIR}/gui/mc_rtc-magnum.cmake)
include(${EXTENSIONS_DIR}/interfaces/mc_mujoco.cmake)

if(WITH_G1)
  AddProject(
    g1_mj_description
    GITHUB Noceo200/g1_mj_description
    GIT_TAG origin/main
    DEPENDS mc_mujoco
  )
endif()

if(WITH_Revo2)
  AddProject(
    revo2_mj_description
    GITHUB isri-aist/revo2_mj_description
    GIT_TAG origin/main
    DEPENDS mc_mujoco
  )
endif()
