/*
 * AM33XX-CM3 firmware
 *
 * Cortex-M3 (CM3) firmware for power management on Texas Instruments' AM33XX series of SoCs
 *
 * Copyright (C) 2011 Texas Instruments Incorporated - http://www.ti.com/
 *
 *  This software is licensed under the  standard terms and conditions in the Texas Instruments  Incorporated
 *  Technology and Software Publicly Available Software License Agreement , a copy of which is included in the
 *  software download.
*/

#ifndef __PRCM_CORE_H__
#define __PRCM_CORE_H__

#define MOSC_OFF		0x0
#define MOSC_ON			0x1

#define DS_COUNT_DEFAULT	0x6A75
#define DS_COUNT_SHIFT		0
#define DS_COUNT_MASK		(0xffff << DS_COUNT_SHIFT)
#define DS_ENABLE_SHIFT		17
#define DS_ENABLE_MASK		(1 << DS_ENABLE_SHIFT)

#define WAKE_ALL		0x17ff	/* all except MPU_WAKE in DS modes */
#define MPU_WAKE		0x800

#define RTC_TIMEOUT_DEFAULT	0x2
#define RTC_TIMEOUT_MAX		0xf

#define AM335X_SOC_ID		0xB944
#define AM335X_REV_ES1_0	0
#define AM335X_REV_ES2_0	1
#define AM335X_REV_ES2_1	2

#define AM43XX_SOC_ID		0xB98C

#define SOC_TYPE_TEST	0
#define SOC_TYPE_EMU	1
#define SOC_TYPE_HS	2
#define SOC_TYPE_GP	3

/* PRM_IO_PMCTRL defs for IO Isolation control */
#define AM43XX_PRM_IO_PMCTRL		0x44DF4024
#define PRM_IO_PMCTRL_IO_ISO_STATUS	(1<<25)
#define PRM_IO_PMCTRL_IO_ISO_CTRL	(1<<24)

extern unsigned int soc_id;
extern unsigned int soc_rev;
extern unsigned int soc_type;

void pm_reset(void);
void setup_soc(void);

int disable_master_oscillator(void);
int enable_master_oscillator(void);

void configure_deepsleep_count(int ds_count);
void configure_wake_sources(int wake_sources);
void clear_wake_sources(void);

void ds_save(void);
void ds_restore(void);

int a8_i2c_sleep_handler(unsigned short);
int a8_i2c_wake_handler(unsigned short);

void prcm_enable_isolation(void);
void prcm_disable_isolation(void);
#endif
