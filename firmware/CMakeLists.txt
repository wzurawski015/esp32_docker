cmake_minimum_required(VERSION 3.16)
include($ENV{IDF_PATH}/tools/cmake/project.cmake)
# Explicit component discovery (IDF doesn't recurse components/)
set(EXTRA_COMPONENT_DIRS
    ${CMAKE_CURRENT_LIST_DIR}/components/ca
    ${CMAKE_CURRENT_LIST_DIR}/components/ports
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_i2c_service
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_uart_port
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_time_port
    ${CMAKE_CURRENT_LIST_DIR}/components/infrastructure/idf_onewire
    ${CMAKE_CURRENT_LIST_DIR}/components/drivers/lcd1602
    ${CMAKE_CURRENT_LIST_DIR}/components/drivers/ds18b20
    ${CMAKE_CURRENT_LIST_DIR}/components/logger_core
    ${CMAKE_CURRENT_LIST_DIR}/components/logger_uart_sink
)
project(esp32c6_extreme_clean_lcd_ds18)
