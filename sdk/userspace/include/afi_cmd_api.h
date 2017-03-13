/*
 * Copyright 2015-2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License"). You may
 * not use this file except in compliance with the License. A copy of the
 * License is located at
 *
 *     http://aws.amazon.com/apache2.0/
 *
 * or in the "license" file accompanying this file. This file is distributed
 * on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
 * express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

/** @file
 * Amazon FPGA Image (AFI) command operations.
 */

#pragma once

#include <stdint.h>
#include <fpga_common.h>

#define AFI_CMD_API_VERSION	2
#define AFI_CMD_DATA_LEN	512 

/** 
 * AFI Protocol:
 *  -one outstanding AFI command is allowed at a time.
 *  -all AFI command fields MUST be in Host Byte Order (Little Endian).
 */
struct afi_cmd_hdr {
	/**< AFI command API version, and reserved bits */
	uint32_t version;
	/**< AFI command opcode, and reserved bits */
	uint32_t op;
	/** 
	 * Length of the payload and flags.
	 * The length of the payload consists of the least significant 
	 * 24-bits while the flags consist of the most-significant 8 bits.
	 * Flags: the least significant bit indicates if it is a request (0)
	 * or a response (1). 
	 */
	uint32_t len_flags;
	/**< VM chosen ID to correlate requests and responses */
	uint32_t id;
} __attribute__((packed));

/**< AFI command structure */
union afi_cmd {
	struct {
		struct afi_cmd_hdr hdr;	/**< AFI cmd header	*/
		uint8_t		body[];		/**< AFI cmd body */
	} __attribute__((packed));
	uint8_t	data[AFI_CMD_DATA_LEN]; /**< Pad buffer to full size */
};

/** AFI command flags */
enum {
	AFI_CMD_HDR_IS_RSP = 1 << 0,
	AFI_CMD_HDR_ALL_FLAGS = AFI_CMD_HDR_IS_RSP,
};

/** 
 * Opcodes:
 *	-new opcodes MUST be added to the end for version compatibility.
 */
enum {
	AFI_CMD_ERROR = 0,		/**< Error response opcode */
	AFI_CMD_LOAD = 1,		/**< Load AFI */
	AFI_CMD_METRICS = 2,	/**< Get loaded metadata Ids, status, stats */
	AFI_CMD_CLEAR = 3,		/**< Clear AFI */
	AFI_CMD_END
};

/** Error response specific info */
union afi_err_info {
	/** 
	 * FPGA_ERR_AFI_CMD_API_VERSION_INVALID: peer's preferred AFI command version.
	 */
	uint32_t	afi_cmd_version;	
};

/** Error response */
struct afi_cmd_err_rsp {
	/** See FPGA_ERR_XXX in fpga_common.h */
	int32_t		error;
	/** See afi_err_info */
	uint8_t		error_info[];			
} __attribute__((packed));

/**< Load AFI request */
struct afi_cmd_load_req {
	struct fpga_meta_ids	ids;
	uint32_t				fpga_cmd_flags; /**< e.g. see FPGA_CMD_ALL_FLAGS */
	struct fpga_common_cfg  cfg;
} __attribute__((packed));

/**< Metrics AFI request */
struct afi_cmd_metrics_req {
	uint32_t				fpga_cmd_flags; /**< e.g. see FPGA_CMD_ALL_FLAGS */
} __attribute__((packed));

/** Metrics AFI response */
struct afi_cmd_metrics_rsp {
	struct fpga_meta_ids	ids;
	int32_t					status; /**< e.g. see FPGA_STATUS_LOADED, fpga_common.h */
	struct fpga_metrics_common	fmc;
} __attribute__((packed));

/**< Clear AFI request */
struct afi_cmd_clear_req {
	uint32_t				fpga_cmd_flags; /**< e.g. see FPGA_CMD_ALL_FLAGS */
} __attribute__((packed));