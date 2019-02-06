cmake_minimum_required(VERSION 2.6)
set(PLATFORM_RPM_REFLEX_DIR ${CMAKE_CURRENT_SOURCE_DIR})

function(check_defined VAR)
    if (NOT ${VAR})
        message(FATAL_ERROR "Required to define ${VAR}")
    endif()
endfunction()

INCLUDE(${CMAKE_SOURCE_DIR}/version.cmake)
set(PROJECT_VERSION ${SUPER_NAME}${SUPER_VERSION})

check_defined(SUPER_NAME)
check_defined(SUPER_VERSION)

#add_custom_target(patch_build_id
#                  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
#                  COMMAND sed -i "s@\\(version_name: \\)\"latest\"@\\1 ${SUPER_VERSION}@" ${CMAKE_CURRENT_SOURCE_DIR}/inventory/templates/group_vars/all/raf/all.yml
#                  VERBATIM)

add_custom_target(cdap_provisioner_rpm ALL
                  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                  COMMAND /usr/local/bin/make-rpm.sh 
                  -s ${CMAKE_CURRENT_SOURCE_DIR}/rpm_conf/cdap-provisoner.spec 
                  -r ${CMAKE_CURRENT_SOURCE_DIR}
                  -o ${PLATFORM_RPM_REFLEX_DIR}
                  --version ${SUPER_VERSION}
                  --release $ENV{RELEASE}
                  VERBATIM)

add_dependencies(cdap_provisioner_rpm patch_build_id)

add_custom_target(raf_push_rpms
                  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                  COMMAND sh ${CMAKE_CURRENT_SOURCE_DIR}/raf-push-rpms ${CMAKE_SOURCE_DIR}  $ENV{BUILD_NUMBER}
                 )
