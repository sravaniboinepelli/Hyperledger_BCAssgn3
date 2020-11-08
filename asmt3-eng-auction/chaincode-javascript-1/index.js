/*
 * Copyright IBM Corp. All Rights Reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 */

'use strict';

const engAuction = require('./lib/engAuction');

module.exports.AssetTransfer = engAuction;
module.exports.contracts = [engAuction];
