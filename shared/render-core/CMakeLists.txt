add_executable(test_build_smoke tests/test_build_smoke.cpp)
add_test(NAME test_build_smoke COMMAND test_build_smoke)

add_executable(test_types tests/test_types.cpp)
target_include_directories(test_types PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_types COMMAND test_types)
