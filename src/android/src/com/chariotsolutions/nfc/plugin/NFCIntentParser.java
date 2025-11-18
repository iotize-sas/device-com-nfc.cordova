package com.chariotsolutions.nfc.plugin;

import android.content.Intent;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.Tag;
import android.os.Parcelable;
import android.util.Log;

import com.iotize.android.device.api.client.IoTizeHelper;
import com.iotize.android.communication.client.impl.protocol.HostProtocol;
import com.iotize.android.core.util.Helper;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;


/**
 *
 */


public class NFCIntentParser {

    private static final String TAG = "NFCTagParser";

    @NonNull
    private final Intent intent;

    @Nullable
    private final Tag tag;
//        private final Context context;

    // PendingIntent used to catch NFC intent sent by system
//        private PendingIntent mPendingIntent = null;
    private NdefRecord[] records;


    public NFCIntentParser(@NonNull Intent intent) {
        this.intent = intent;
        this.tag = NFCIntentParser.extractTag(intent);
        parseRecords();
    }

    public static boolean hasNFCTag(Intent intent){
       return NFCIntentParser.extractTag(intent) != null;
    }

    @Nullable
    public Tag getTag() {
        return tag;
    }

//        public void check() {
//
//            // Declare NFC Intent to survey
//            mPendingIntent = PendingIntent.getActivity(context, 0, new Intent(context, getClass()).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP), 0);
//            IntentFilter ndef = new IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED);
//            IntentFilter[] mFilters = new IntentFilter[]{ndef,};
////XD 240717
//            String[][] mTechLists = new String[][]{new String[]{IsoDep.class.getName(), Ndef.class.getName(), NfcA.class.getName(), NfcV.class.getName()}};
//
//            ResolveIntent(intent, false);
//
//        }

    protected void parseRecords() {
        // read all NDEF messages
        Parcelable[] rawMsgs = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES);

        if (rawMsgs == null || rawMsgs.length == 0) {
            return;
        }

        NdefMessage[] msgs = new NdefMessage[rawMsgs.length];
        for (int i = 0; i < rawMsgs.length; i++) {
            msgs[i] = (NdefMessage) rawMsgs[i];
        }
        records = msgs[0].getRecords();
    }

    public boolean hasRecords(){
        return records != null && records.length > 0;
    }

    public HostProtocol getAvailableProtocol() {
        if (records != null && records.length >= 3) {
            // We manage only on NDEF message with 3 records:
            // record 0 = URI; record 1 = AAR; record 2 = BD_ADDR / BSSID
            NdefRecord record = records[2];
            byte[] payload = record.getPayload();
            if (payload == null || payload.length == 0) {
                Log.w(TAG, "Invalid payload for record 2. Available records are: " + records);
                return null;
            }

            switch ((int) payload[0]) {
                case IoTizeHelper.HostProtocol.BLE:
                    return HostProtocol.BLE;
                case IoTizeHelper.HostProtocol.BT:
                    return HostProtocol.BLUETOOTH;
                case IoTizeHelper.HostProtocol.WiFi:
                    return HostProtocol.WIFI;
                default:
                    Log.w(TAG, "Unknown connection protocol code: " + Integer.valueOf(payload[0]));
                    return null;
            }
        }
        return null;
    }

//    public ConnectionInfo getAlternativeConnectionMode() {
//        HostProtocol connectionProtocolCode = this.getAvailableProtocol();
//
//        if (connectionProtocolCode == null) {
//            Log.w(TAG, "No connection protocol available");
//            return null;
//        }
//
//        byte[] payload = getPayload();
//
//        switch (connectionProtocolCode) {
//            case BLE:
//            case BT:
//                // Get the BluetoothDevice object
//                Log.d(TAG, "BT device detected: " + addressIoTize);
//
//                return new ConnectionInfo<>(HostProtocol.BLE, new BLEConnectionInfo(addressIoTize));
//            case WIFI:
//
//                String ssidIoTize = new String(payload);
//                ssidIoTize = ssidIoTize.substring(1);
//
//                WifiConfiguration wifiConfig = new WifiConfiguration();
//                wifiConfig.SSID = ssidIoTize;
//
//                return new ConnectionInfo<>(HostProtocol.WIFI, wifiConfig);
//            default:
//                Log.w(TAG, "Unknown connection protocol code: " + connectionProtocolCode);
//                return null;
//        }
//    }

    public String getSSID() {
        // TODO exception if not formatted correcly ?
        String ssidIoTize = new String(getPayload());
        ssidIoTize = ssidIoTize.substring(1);
        return ssidIoTize;
    }

    public byte[] getPayload() {
        // TODO exception if out of bound ?
        NdefRecord addressRecord = records[2];
        return addressRecord.getPayload();
    }

    public String getMacAddress() {
        // TODO exception if not formatted correctly ?
        byte[] payload = getPayload();
        // Get the BD_ADDR os the selected device
        String add = Helper.ByteArrayToHexString(payload);

        String addressIoTize = "";
        for (int i = 6; i >= 1; i--) {
            addressIoTize += add.substring(2 * i, (2 * i) + 2);
            if (i > 1)
                addressIoTize += ":";
        }

        return addressIoTize;
    }

    public Intent getIntent() {
        return intent;
    }

    @Nullable
    public static Tag extractTag(Intent intent) {
        String action = intent.getAction();
        if ((NfcAdapter.ACTION_NDEF_DISCOVERED.equals(action)) || (NfcAdapter.ACTION_TECH_DISCOVERED.equals(action)) || (NfcAdapter.ACTION_TAG_DISCOVERED.equals(action))) {
            return intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
        }
        return null;
    }
}