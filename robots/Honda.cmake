option(WITH_Honda "Build with Honda hands support" OFF)

if(NOT WITH_Honda)
  return()
endif()

if(ROS_IS_ROS2)
    AddCatkinProject(
      ur_description
      GITHUB UniversalRobots/Universal_Robots_ROS2_Description
      GIT_TAG origin/${ROS_DISTRO}
      WORKSPACE data_ws
    )
  else() # ROS1
    AddCatkinProject(
      ur_description
      GITHUB ros-industrial/universal_robot
      GIT_TAG noetic-devel/ur_description
      WORKSPACE data_ws
    )
endif()

AddCatkinProject(
  honda_description
  GITE onoel/honda_description
  GIT_TAG origin/main
  WORKSPACE data_ws
)

AddProject(
  mc_honda
  GITE onoel/mc_honda
  GIT_TAG origin/main
  DEPENDS honda_description mc_rtc
)


