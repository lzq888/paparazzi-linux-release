#ifndef I2C_H
#define I2C_H

#include "std.h"

#include "i2c_hw.h"

#define I2C_START        0x08
#define I2C_RESTART      0x10
#define I2C_MT_SLA_ACK   0x18
#define I2C_MT_SLA_NACK  0x20
#define I2C_MT_DATA_ACK  0x28
#define I2C_MR_SLA_ACK   0x40
#define I2C_MR_SLA_NACK  0x48
#define I2C_MR_DATA_ACK  0x50
#define I2C_MR_DATA_NACK 0x58


#define I2C_IDLE 0
#define I2C_BUSY 1

#ifdef USE_I2C0

extern void i2c0_init(void);
extern void i2c0_receive(uint8_t slave_addr, uint8_t len, volatile bool_t* finished);
extern void i2c0_transmit(uint8_t slave_addr, uint8_t len, volatile bool_t* finished);

extern volatile uint8_t i2c0_status;

#ifndef I2C0_BUF_LEN
#define I2C0_BUF_LEN 16
#endif

extern volatile uint8_t i2c0_buf[I2C0_BUF_LEN];
extern volatile uint8_t i2c0_len;
extern volatile uint8_t i2c0_index;
extern volatile uint8_t i2c0_slave_addr;

extern volatile bool_t* i2c0_finished;

#define I2c0Automaton(state) {						\
    switch (state) {							\
    case I2C_START:							\
    case I2C_RESTART:							\
      I2c0SendByte(i2c0_slave_addr);					\
      I2c0ClearStart();							\
      i2c0_index = 0;							\
      break;								\
    case I2C_MR_DATA_ACK:						\
      if (i2c0_index < i2c0_len) {					\
	i2c0_buf[i2c0_index] = I2C_DATA_REG;				\
	i2c0_index++;							\
	I2c0Receive(i2c0_index < i2c0_len - 1);				\
      }									\
      else {								\
	/* error , we should have got NACK */				\
	I2c0SendStop();							\
      }									\
      break;								\
    case I2C_MR_SLA_ACK: /* At least one char */			\
      /* Wait and reply with ACK or NACK */				\
      I2c0Receive(i2c0_index < i2c0_len - 1);				\
      break;								\
    case I2C_MR_SLA_NACK:						\
    case I2C_MT_SLA_NACK:						\
      I2c0SendStart();							\
      break;								\
    case I2C_MT_SLA_ACK:						\
    case I2C_MT_DATA_ACK:						\
      if (i2c0_index < i2c0_len) {					\
	I2c0SendByte(i2c0_buf[i2c0_index]);				\
	i2c0_index++;							\
      } else {								\
	I2c0SendStop();							\
      }									\
      break;								\
    case I2C_MR_DATA_NACK:						\
      if (i2c0_index < i2c0_len) {					\
	i2c0_buf[i2c0_index] = I2C_DATA_REG;				\
      }									\
      I2c0SendStop();							\
      break;								\
    default:								\
      I2c0SendStop();							\
      /* FIXME log error */						\
    }									\
  }									\

#endif /* USE_I2C0 */   

#ifdef USE_I2C1

extern void i2c1_init(void);
extern void i2c1_receive(uint8_t slave_addr, uint8_t len, volatile bool_t* finished);
extern void i2c1_transmit(uint8_t slave_addr, uint8_t len, volatile bool_t* finished);

extern volatile uint8_t i2c1_status;

#ifndef I2C1_BUF_LEN
#define I2C1_BUF_LEN 16
#endif

extern volatile uint8_t i2c1_buf[I2C1_BUF_LEN];
extern volatile uint8_t i2c1_len;
extern volatile uint8_t i2c1_index;
extern volatile uint8_t i2c1_slave_addr;

extern volatile bool_t* i2c1_finished;

#define I2c1Automaton(state) {						\
    switch (state) {							\
    case I2C_START:							\
    case I2C_RESTART:							\
      I2c1SendByte(i2c1_slave_addr);					\
      I2c1ClearStart();							\
      i2c1_index = 0;							\
      break;								\
    case I2C_MR_DATA_ACK:						\
      if (i2c1_index < i2c1_len) {					\
	i2c1_buf[i2c1_index] = I2C1_DATA_REG;				\
	i2c1_index++;							\
	I2c1Receive(i2c1_index < i2c1_len - 1);				\
      }									\
      else {								\
	/* error , we should have got NACK */				\
	I2c1SendStop();							\
      }									\
      break;								\
    case I2C_MR_SLA_ACK: /* At least one char */			\
      /* Wait and reply with ACK or NACK */				\
      I2c1Receive(i2c1_index < i2c1_len - 1);				\
      break;								\
    case I2C_MR_SLA_NACK:						\
    case I2C_MT_SLA_NACK:						\
      I2c1SendStart();							\
      break;								\
    case I2C_MT_SLA_ACK:						\
    case I2C_MT_DATA_ACK:						\
      if (i2c1_index < i2c1_len) {					\
	I2c1SendByte(i2c1_buf[i2c1_index]);				\
	i2c1_index++;							\
      } else {								\
	I2c1SendStop();							\
      }									\
      break;								\
    case I2C_MR_DATA_NACK:						\
      if (i2c1_index < i2c1_len) {					\
	i2c1_buf[i2c1_index] = I2C1_DATA_REG;				\
      }									\
      I2c1SendStop();							\
      break;								\
    default:								\
      I2c1SendStop();							\
      /* LED_ON(2); FIXME log error */					\
    }									\
  }									\
   


#endif /* USE_I2C1 */


#endif /* I2C_H */
