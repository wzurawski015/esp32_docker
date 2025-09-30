idf_component_register(
  SRCS "main.c"
  INCLUDE_DIRS "."
  REQUIRES
    ca ports
    infrastructure__idf_i2c_service
    infrastructure__idf_uart_port
    infrastructure__idf_time_port
    infrastructure__idf_onewire
    drivers__lcd1602 drivers__ds18b20
    logger_core logger_uart_sink
)
