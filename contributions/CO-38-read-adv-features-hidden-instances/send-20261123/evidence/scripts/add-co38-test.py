#!/usr/bin/env python3
"""add-co38-test.py <mgmt-tester.c>: add "Read Advertising Features - Success 3 (Instance 2 only)".

One advertising instance numbered 2 is added, then Read Advertising Features must list exactly
that instance. The kernel compares instance numbers with adv_instance_cnt (1 here), so without the
fix instance 2 is left out. The setup reuses setup_add_advertising()'s body through a helper taking
the instance number.
"""
import sys

p = sys.argv[1]
s = open(p, encoding="utf-8").read()


def once(old, new):
    global s
    n = s.count(old)
    if n != 1:
        sys.exit(f"anchor found {n} times: {old[:60]!r}")
    s = s.replace(old, new)


T = "\t"
rsp_anchor = ("static const struct generic_data read_adv_features_success_2 = {\n"
              f"{T}.send_opcode = MGMT_OP_READ_ADV_FEATURES,\n"
              f"{T}.expect_param = read_adv_features_rsp_2,\n"
              f"{T}.expect_len = sizeof(read_adv_features_rsp_2),\n"
              f"{T}.expect_status = MGMT_STATUS_SUCCESS,\n"
              "};\n")
once(rsp_anchor, rsp_anchor + (
    "\n"
    "static const uint8_t read_adv_features_rsp_instance_2[] =  {\n"
    f"{T}0x7f, 0xf0, 0x01, 0x00,{T}/* supported flags */\n"
    f"{T}0x1f,{T}{T}{T}/* max_adv_data_len */\n"
    f"{T}0x1f,{T}{T}{T}/* max_scan_rsp_len */\n"
    f"{T}0x05,{T}{T}{T}/* max_instances */\n"
    f"{T}0x01,{T}{T}{T}/* num_instances */\n"
    f"{T}0x02,{T}{T}{T}/* instance identifiers */\n"
    "};\n"
    "\n"
    "static const struct generic_data read_adv_features_instance_2 = {\n"
    f"{T}.send_opcode = MGMT_OP_READ_ADV_FEATURES,\n"
    f"{T}.expect_param = read_adv_features_rsp_instance_2,\n"
    f"{T}.expect_len = sizeof(read_adv_features_rsp_instance_2),\n"
    f"{T}.expect_status = MGMT_STATUS_SUCCESS,\n"
    "};\n"))

body = (f"{T}struct test_data *data = tester_get_data();\n"
        f"{T}struct mgmt_cp_add_advertising *cp;\n"
        f"{T}unsigned char adv_param[sizeof(*cp) + TESTER_ADD_ADV_DATA_LEN];\n"
        f"{T}unsigned char param[] = {{ 0x01 }};\n\n")
once("static void setup_add_advertising(const void *test_data)\n{\n" + body +
     f"{T}tester_print(\"Adding advertising instance while powered\");\n\n"
     f"{T}cp = (struct mgmt_cp_add_advertising *) adv_param;\n"
     f"{T}setup_add_adv_param(cp, 1);\n",
     "static void add_advertising_instance(uint8_t instance)\n{\n" + body +
     f"{T}tester_print(\"Adding advertising instance %u while powered\", instance);\n\n"
     f"{T}cp = (struct mgmt_cp_add_advertising *) adv_param;\n"
     f"{T}setup_add_adv_param(cp, instance);\n")
end_anchor = (f"{T}mgmt_send(data->mgmt, MGMT_OP_ADD_ADVERTISING, data->mgmt_index,\n"
              f"{T}{T}{T}{T}{T}{T}sizeof(adv_param), adv_param,\n"
              f"{T}{T}{T}{T}{T}{T}setup_add_advertising_callback,\n"
              f"{T}{T}{T}{T}{T}{T}NULL, NULL);\n"
              "}\n\n"
              "static void setup_add_advertising_connectable(const void *test_data)\n")
once(end_anchor, end_anchor.replace(
    "}\n\nstatic void setup_add_advertising_connectable",
    "}\n\n"
    "static void setup_add_advertising(const void *test_data)\n{\n"
    f"{T}add_advertising_instance(1);\n"
    "}\n\n"
    "static void setup_add_advertising_2(const void *test_data)\n{\n"
    f"{T}add_advertising_instance(2);\n"
    "}\n\n"
    "static void setup_add_advertising_connectable"))

reg = (f"{T}test_bredrle(\"Read Advertising Features - Success 2 (One instance)\",\n"
       f"{T}{T}{T}{T}&read_adv_features_success_2,\n"
       f"{T}{T}{T}{T}setup_add_advertising,\n"
       f"{T}{T}{T}{T}test_command_generic);\n")
once(reg, reg +
     f"{T}test_bredrle(\"Read Advertising Features - Success 3 (Instance 2 only)\",\n"
     f"{T}{T}{T}{T}&read_adv_features_instance_2,\n"
     f"{T}{T}{T}{T}setup_add_advertising_2,\n"
     f"{T}{T}{T}{T}test_command_generic);\n")

open(p, "w", encoding="utf-8").write(s)
print("added")
