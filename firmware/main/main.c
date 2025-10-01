#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"
#include "driver/i2c_master.h"

#define TAG         "DFR_LCD"
#define SDA_PIN     10            // ESP32-C6 DevKitC-1
#define SCL_PIN     11
#define I2C_HZ      100000        // start safe
#define LCD_ADDR    0x3E          // AIP31068/ST7032 (DFR0464)
#define RGB_ADDR    0x2D          // DFR0464 V2.0 RGB

static i2c_master_bus_handle_t bus;
static i2c_master_dev_handle_t lcd, rgb;

static esp_err_t i2c_setup(void)
{
    i2c_master_bus_config_t bus_cfg = {
        .i2c_port = I2C_NUM_0,
        .sda_io_num = SDA_PIN,
        .scl_io_num = SCL_PIN,
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .glitch_ignore_cnt = 7,
        .flags = { .enable_internal_pullup = true }, // można false; moduł ma swoje pull-upy
    };
    ESP_ERROR_CHECK(i2c_new_master_bus(&bus_cfg, &bus));

    // sprawdź obecność urządzeń
    ESP_LOGI(TAG, "I2C scan begin");
    for (int a = 1; a < 0x7F; ++a) {
        if (i2c_master_probe(bus, a, 20) == ESP_OK) {
            ESP_LOGI(TAG, "found 0x%02X", a);
        }
    }
    ESP_LOGI(TAG, "I2C scan end");

    i2c_device_config_t lcd_cfg = {
        .device_address = LCD_ADDR,
        .scl_speed_hz  = I2C_HZ,
    };
    ESP_ERROR_CHECK(i2c_master_bus_add_device(bus, &lcd_cfg, &lcd));

    i2c_device_config_t rgb_cfg = {
        .device_address = RGB_ADDR,
        .scl_speed_hz  = I2C_HZ,
    };
    // RGB może nie istnieć -> nie przerywaj aplikacji
    esp_err_t e = i2c_master_bus_add_device(bus, &rgb_cfg, &rgb);
    if (e != ESP_OK) {
        ESP_LOGW(TAG, "RGB controller 0x%02X not found", RGB_ADDR);
        rgb = NULL;
    }
    return ESP_OK;
}

static inline esp_err_t lcd_cmd(uint8_t c)
{
    uint8_t buf[2] = {0x80, c};        // 0x80 = control byte "command"
    return i2c_master_transmit(lcd, buf, 2, 20);
}

static inline esp_err_t lcd_data(uint8_t d)
{
    uint8_t buf[2] = {0x40, d};        // 0x40 = control byte "data"
    return i2c_master_transmit(lcd, buf, 2, 20);
}

static void lcd_init(void)
{
    vTaskDelay(pdMS_TO_TICKS(50));
    const uint8_t LCD_FUNCTIONSET      = 0x20;
    const uint8_t LCD_DISPLAYCONTROL   = 0x08;
    const uint8_t LCD_CLEARDISPLAY     = 0x01;
    const uint8_t LCD_ENTRYMODESET     = 0x04;

    const uint8_t LCD_2LINE            = 0x08;
    const uint8_t LCD_5x8DOTS          = 0x00;
    const uint8_t LCD_DISPLAYON        = 0x04;
    const uint8_t LCD_CURSOROFF        = 0x00;
    const uint8_t LCD_BLINKOFF         = 0x00;
    const uint8_t LCD_ENTRYLEFT        = 0x02;
    const uint8_t LCD_ENTRYSHIFTDECR   = 0x00;

    uint8_t showfunc   = LCD_2LINE | LCD_5x8DOTS; // (4-bit przez I2C)
    (void)lcd_cmd(LCD_FUNCTIONSET | showfunc); vTaskDelay(pdMS_TO_TICKS(5));
    (void)lcd_cmd(LCD_FUNCTIONSET | showfunc); vTaskDelay(pdMS_TO_TICKS(5));
    (void)lcd_cmd(LCD_FUNCTIONSET | showfunc);

    uint8_t showctrl  = LCD_DISPLAYON | LCD_CURSOROFF | LCD_BLINKOFF;
    (void)lcd_cmd(LCD_DISPLAYCONTROL | showctrl);

    (void)lcd_cmd(LCD_CLEARDISPLAY);
    vTaskDelay(pdMS_TO_TICKS(2));

    uint8_t showmode  = LCD_ENTRYLEFT | LCD_ENTRYSHIFTDECR;
    (void)lcd_cmd(LCD_ENTRYMODESET | showmode);
}

static void lcd_set_cursor(uint8_t col, uint8_t row)
{
    static const uint8_t row_addr[] = {0x00, 0x40, 0x14, 0x54};
    uint8_t addr = (row < 4 ? row_addr[row] : row_addr[0]) + col;
    (void)lcd_cmd(0x80 | addr);
}

static void lcd_print(const char *s)
{
    while (*s) (void)lcd_data((uint8_t)*s++);
}

static void rgb_write(uint8_t reg, uint8_t val)
{
    if (!rgb) return;
    uint8_t buf[2] = {reg, val};
    (void)i2c_master_transmit(rgb, buf, 2, 20);
}

static void rgb_init_white(void)
{
    // wg biblioteki DFRobot
    const uint8_t REG_MODE1   = 0x00;
    const uint8_t REG_MODE2   = 0x01;
    const uint8_t REG_OUTPUT  = 0x08;
    const uint8_t REG_BLUE    = 0x02;
    const uint8_t REG_GREEN   = 0x03;
    const uint8_t REG_RED     = 0x04;

    rgb_write(REG_MODE1, 0x00);
    rgb_write(REG_OUTPUT, 0xFF);
    rgb_write(REG_MODE2, 0x20);     // DMBLNK=1

    // biały
    rgb_write(REG_RED,   255);
    rgb_write(REG_GREEN, 255);
    rgb_write(REG_BLUE,  255);
}

void app_main(void)
{
    ESP_ERROR_CHECK(i2c_setup());

    // Jeśli któregoś adresu nie ma – zweryfikuj zasilanie/piny (3V3, GPIO10/11)
    if (i2c_master_probe(bus, LCD_ADDR, 20) != ESP_OK) {
        ESP_LOGE(TAG, "LCD 0x%02X not found", LCD_ADDR);
        vTaskDelete(NULL);
    }

    lcd_init();
    if (rgb) rgb_init_white();

    lcd_set_cursor(0, 0);
    lcd_print("ESP32-C6 OK");
    lcd_set_cursor(0, 1);
    lcd_print("DFR0464 RGB");

    while (1) vTaskDelay(pdMS_TO_TICKS(1000));
}
