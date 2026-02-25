add_executable(test_build_smoke tests/test_build_smoke.cpp)
add_test(NAME test_build_smoke COMMAND test_build_smoke)

add_executable(test_types tests/test_types.cpp)
target_include_directories(test_types PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_types COMMAND test_types)

add_executable(test_state_machine tests/test_state_machine.cpp src/state_machine.cpp)
target_include_directories(test_state_machine PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_state_machine COMMAND test_state_machine)

add_executable(test_resolution_selector tests/test_resolution_selector.cpp src/resolution_selector.cpp)
target_include_directories(test_resolution_selector PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_resolution_selector COMMAND test_resolution_selector)
