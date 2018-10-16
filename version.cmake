
execute_process(COMMAND date +"%Y-%m-%d %H:%M:%S"
                COMMAND tr "\n" " "
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_VARIABLE BUILD_DATE)

execute_process(COMMAND hostname
                COMMAND tr "\n" " "
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_VARIABLE BUILD_HOST)

execute_process(COMMAND git log -1 --format="%H [%ai]"
                COMMAND tr "\n" " "
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                OUTPUT_VARIABLE VERSION)

add_definitions(-DVERSION=${VERSION} -DBUILD_HOST=\"${BUILD_HOST}\" -DBUILD_DATE=${BUILD_DATE})

execute_process(COMMAND git remote -v 
                COMMAND tail -1
                COMMAND awk -F/ "{print $NF}"
                COMMAND cut -f1 -d.
                COMMAND tr "\n" " "
                COMMAND sed -e "s/ //"
                WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                OUTPUT_VARIABLE SUPER_NAME)

execute_process(COMMAND cat VERSION
                COMMAND tr "\n" " "
                COMMAND sed -e "s/ //"
                WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}
                OUTPUT_VARIABLE SUPER_VERSION)

