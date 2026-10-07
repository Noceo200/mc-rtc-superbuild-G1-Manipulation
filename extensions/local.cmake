set(EXTENSIONS_DIR ${CMAKE_CURRENT_LIST_DIR}/superbuild-extensions)
include(${EXTENSIONS_DIR}/gui/mc_rtc-magnum.cmake)
include(${EXTENSIONS_DIR}/interfaces/mc_mujoco.cmake)

AddProject(
    mc_isaac
    GITHUB isri-aist/mc_isaac
    GIT_TAG origin/main
  )

AddProject(
    mc_nn
    GITHUB isri-aist/mc_nn
    GIT_TAG origin/main
  )

AddProject(
    mc_manipulation_objects
    GITHUB Noceo200/mc_manipulation_objects
    GIT_TAG origin/main
  )
  
if(WITH_G1)
  AddProject(
    g1_mj_description
    GITHUB Noceo200/g1_mj_description
    GIT_TAG origin/main
    DEPENDS mc_mujoco
  )

  AddProject(
    g1_isaac_description
    GITHUB isri-aist/g1_isaac_description
    GIT_TAG origin/main
    DEPENDS mc_isaac
  )
  #[[
  AddProject(mc_unitree2
    GITHUB y-hadj/mc_unitree2_wG1
    GIT_TAG master
    DEPENDS mc_rtc 
    CMAKE_ARGS -DGENERATE_G1_REVO2_CONTROLLER=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
  )
  ]]
endif()

if(WITH_Revo2)
  AddProject(
    revo2_mj_description
    GITHUB isri-aist/revo2_mj_description
    GIT_TAG origin/main
    DEPENDS mc_mujoco
  )
  AddProject(
    revo2_isaac_description
    GITHUB isri-aist/revo2_isaac_description
    GIT_TAG origin/main
    DEPENDS mc_isaac
  )
endif()

if(WITH_Honda)
  AddProject(
    honda_mj_description
    GITE onoel/honda_mj_description
    GIT_TAG origin/main
    DEPENDS mc_mujoco
  )
  AddProject(
    honda_isaac_description
    GITE onoel/honda_isaac_description
    GIT_TAG origin/main
    DEPENDS mc_isaac
  )
endif()

