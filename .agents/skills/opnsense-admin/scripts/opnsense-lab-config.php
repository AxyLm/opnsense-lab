#!/usr/bin/env php
<?php
// Apply this repository's static LAN and PORTAL lab defaults inside OPNsense.

$config_path = getenv('OPNSENSE_CONFIG_PATH') ?: '/conf/config.xml';
$backup_path = $config_path . '.lab-static-bak-' . date('YmdHis');

$lan_device = getenv('OPNSENSE_LAN_DEVICE') ?: 'em0';
$lan_interface = getenv('OPNSENSE_LAN_INTERFACE') ?: 'lan';
$lan_descr = getenv('OPNSENSE_LAN_DESCR') ?: 'LAN';
$lan_ip = getenv('OPNSENSE_LAN_IP') ?: '192.168.60.254';
$lan_subnet = getenv('OPNSENSE_LAN_SUBNET') ?: '24';

$portal_device = getenv('OPNSENSE_PORTAL_DEVICE') ?: 'em2';
$portal_interface = getenv('OPNSENSE_PORTAL_INTERFACE') ?: 'opt1';
$portal_descr = getenv('OPNSENSE_PORTAL_DESCR') ?: 'PORTAL';
$portal_ip = getenv('OPNSENSE_PORTAL_IP') ?: '192.168.70.254';
$portal_subnet = getenv('OPNSENSE_PORTAL_SUBNET') ?: '24';
$portal_rule_descr = getenv('OPNSENSE_PORTAL_RULE_DESCR') ?: 'Allow PORTAL lab to any';
$portal_zone_descr = getenv('OPNSENSE_PORTAL_ZONE_DESCR') ?: 'portal-lab';
$portal_servername = getenv('OPNSENSE_PORTAL_SERVERNAME') ?: $portal_ip;

$xml = simplexml_load_file($config_path);
if ($xml === false) {
    fwrite(STDERR, "failed to load config: $config_path\n");
    exit(1);
}

if (!copy($config_path, $backup_path)) {
    fwrite(STDERR, "failed to create backup: $backup_path\n");
    exit(1);
}

function put_value($node, $key, $value) {
    if (!isset($node->{$key})) {
        $node->addChild($key);
    }
    $node->{$key} = $value;
}

function ensure_interface($xml, $name, $device, $descr, $ipaddr, $subnet) {
    if (!isset($xml->interfaces->{$name})) {
        $xml->interfaces->addChild($name);
    }

    $iface = $xml->interfaces->{$name};
    foreach ([
        'if' => $device,
        'descr' => $descr,
        'enable' => '1',
        'ipaddr' => $ipaddr,
        'subnet' => $subnet,
        'blockpriv' => '0',
        'blockbogons' => '0',
    ] as $key => $value) {
        put_value($iface, $key, $value);
    }
}

ensure_interface($xml, $lan_interface, $lan_device, $lan_descr, $lan_ip, $lan_subnet);
ensure_interface($xml, $portal_interface, $portal_device, $portal_descr, $portal_ip, $portal_subnet);

if (!isset($xml->filter)) {
    $xml->addChild('filter');
}

$rule_exists = false;
foreach ($xml->filter->rule as $rule) {
    if ((string)$rule->descr === $portal_rule_descr) {
        $rule_exists = true;
        break;
    }
}

if (!$rule_exists) {
    $rule = $xml->filter->addChild('rule');
    $rule->addChild('type', 'pass');
    $rule->addChild('ipprotocol', 'inet');
    $rule->addChild('descr', $portal_rule_descr);
    $rule->addChild('interface', $portal_interface);
    $source = $rule->addChild('source');
    $source->addChild('network', $portal_interface);
    $destination = $rule->addChild('destination');
    $destination->addChild('any');
}

if (isset($xml->OPNsense->captiveportal->zones->zone)) {
    $zone = $xml->OPNsense->captiveportal->zones->zone;
    foreach ([
        'enabled' => '1',
        'interfaces' => $portal_interface,
        'disableRules' => '0',
        'servername' => $portal_servername,
        'description' => $portal_zone_descr,
    ] as $key => $value) {
        put_value($zone, $key, $value);
    }
}

$dom = dom_import_simplexml($xml)->ownerDocument;
$dom->formatOutput = true;
$dom->save($config_path);

echo "backup=$backup_path\n";
echo "lan_interface=$lan_interface\n";
echo "lan_device=$lan_device\n";
echo "lan_ip=$lan_ip/$lan_subnet\n";
echo "portal_interface=$portal_interface\n";
echo "portal_device=$portal_device\n";
echo "portal_ip=$portal_ip/$portal_subnet\n";
echo "portal_servername=$portal_servername\n";
?>
