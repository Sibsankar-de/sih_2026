cmake_minimum_required(VERSION 3.14)
project(fusion_engine VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Find Eigen3 — try system first, fetch if not found
find_package(Eigen3 3.3 QUIET NO_MODULE)
if(NOT Eigen3_FOUND)
    message(STATUS "Eigen3 not found on system, fetching via FetchContent...")
    include(FetchContent)
    FetchContent_Declare(
        eigen3
        GIT_REPOSITORY https://gitlab.com/libeigen/eigen.git
        GIT_TAG 3.4.0
        GIT_SHALLOW TRUE
    )
    set(EIGEN_BUILD_DOC OFF CACHE BOOL "" FORCE)
    set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(EIGEN_BUILD_PKGCONFIG OFF CACHE BOOL "" FORCE)
    FetchContent_MakeAvailable(eigen3)
endif()

# Main library
add_library(fusion_engine
    src/ekf.cpp
    src/fusion_engine.cpp
    src/local_frame.cpp
    src/noise_model.cpp
    src/measurement_gating.cpp
)
target_include_directories(fusion_engine PUBLIC
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    $<INSTALL_INTERFACE:include>
)
target_link_libraries(fusion_engine PUBLIC Eigen3::Eigen)

# Compiler warnings
target_compile_options(fusion_engine PRIVATE
    $<$<CXX_COMPILER_ID:GNU,Clang>:-Wall -Wextra -Wpedantic>
)

# Example executable
add_executable(fusion_example examples/main.cpp)
target_link_libraries(fusion_example PRIVATE fusion_engine)

# Testing
option(BUILD_TESTS "Build unit tests" ON)
if(BUILD_TESTS)
    enable_testing()
    
    # Fetch GoogleTest
    include(FetchContent)
    FetchContent_Declare(
        googletest
        GIT_REPOSITORY https://github.com/google/googletest.git
        GIT_TAG v1.14.0
    )
    FetchContent_MakeAvailable(googletest)
    
    # Test executables
    set(TEST_SOURCES
        tests/test_local_frame.cpp
        tests/test_prediction.cpp
        tests/test_gnss.cpp
        tests/test_ml_velocity.cpp
        tests/test_nhc.cpp
        tests/test_zupt.cpp
        tests/test_gating.cpp
        tests/test_outage_recovery.cpp
    )
    
    foreach(test_source ${TEST_SOURCES})
        get_filename_component(test_name ${test_source} NAME_WE)
        add_executable(${test_name} ${test_source})
        target_link_libraries(${test_name} PRIVATE fusion_engine GTest::gtest_main)
        add_test(NAME ${test_name} COMMAND ${test_name})
    endforeach()
endif()

# Shared library option (for Android JNI later)
option(BUILD_SHARED "Build shared library" OFF)
if(BUILD_SHARED)
    add_library(fusion_engine_shared SHARED
        src/ekf.cpp
        src/fusion_engine.cpp
        src/local_frame.cpp
        src/noise_model.cpp
        src/measurement_gating.cpp
    )
    target_include_directories(fusion_engine_shared PUBLIC
        $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
    )
    target_link_libraries(fusion_engine_shared PUBLIC Eigen3::Eigen)
    set_target_properties(fusion_engine_shared PROPERTIES OUTPUT_NAME fusion_engine)
endif()
