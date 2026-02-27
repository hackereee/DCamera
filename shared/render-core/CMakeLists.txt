cmake_minimum_required(VERSION 3.14)
project(render-core-tests CXX)
enable_testing()

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

add_executable(test_render_pipeline tests/test_render_pipeline.cpp src/render_pipeline.cpp)
target_include_directories(test_render_pipeline PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_render_pipeline COMMAND test_render_pipeline)

add_executable(test_metrics_contract tests/test_metrics_contract.cpp)
target_include_directories(test_metrics_contract PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
add_test(NAME test_metrics_contract COMMAND test_metrics_contract)

add_library(scamera_render_core STATIC
    src/render_pipeline.cpp
    src/render_pipeline_c.cpp
)
target_include_directories(scamera_render_core PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

add_executable(test_render_pipeline_c tests/test_render_pipeline_c.cpp)
target_link_libraries(test_render_pipeline_c PRIVATE scamera_render_core)
add_test(NAME test_render_pipeline_c COMMAND test_render_pipeline_c)
