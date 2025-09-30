idf_component_register(SRCS "src/idf_i2c_service.c"
                       INCLUDE_DIRS "include"
                       REQUIRES driver freertos ca ports)
