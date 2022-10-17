package com.chariotsolutions.nfc.plugin;

import android.app.Activity;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.IntentFilter.MalformedMimeTypeException;
import android.net.Uri;
import android.nfc.FormatException;
import android.nfc.NdefMessage;
import android.nfc.NdefRecord;
import android.nfc.NfcAdapter;
import android.nfc.NfcEvent;
import android.nfc.Tag;
import android.nfc.TagLostException;
import android.nfc.tech.Ndef;
import android.nfc.tech.NdefFormatable;
import android.os.Bundle;
import android.os.Parcelable;
import android.util.Log;
import android.widget.Toast;

import com.iotize.android.communication.client.impl.EncryptionAlgo;
import com.iotize.android.communication.client.impl.TapClient;
import com.iotize.android.communication.client.impl.protocol.ProtocolFactory;
import com.iotize.android.communication.protocol.nfc.NFCIntentParser;
import com.iotize.android.communication.protocol.nfc.NFCProtocol;
import com.iotize.android.communication.protocol.nfc.NFCProtocolFactory;
import com.iotize.android.core.util.Helper;
import com.iotize.android.device.device.impl.IoTizeDevice;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaArgs;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;

import io.reactivex.annotations.NonNull;
import io.reactivex.annotations.Nullable;

// using wildcard imports so we can support Cordova 3.x

public class NfcPlugin extends CordovaPlugin implements NfcAdapter.OnNdefPushCompleteCallback {
    private static final String REGISTER_MIME_TYPE = "registerMimeType";
    private static final String REMOVE_MIME_TYPE = "removeMimeType";
    private static final String REGISTER_NDEF = "registerNdef";
    private static final String REMOVE_NDEF = "removeNdef";
    private static final String REGISTER_NDEF_FORMATABLE = "registerNdefFormatable";
    private static final String REGISTER_DEFAULT_TAG = "registerTag";
    private static final String REMOVE_DEFAULT_TAG = "removeTag";
    private static final String WRITE_TAG = "writeTag";
    private static final String MAKE_READ_ONLY = "makeReadOnly";
    private static final String ERASE_TAG = "eraseTag";
    private static final String SHARE_TAG = "shareTag";
    private static final String UNSHARE_TAG = "unshareTag";
    private static final String HANDOVER = "handover"; // Android Beam
    private static final String STOP_HANDOVER = "stopHandover";
    private static final String ENABLED = "enabled";
    private static final String INIT = "init";
    private static final String SHOW_SETTINGS = "showSettings";

    private static final String NDEF = "ndef";
    private static final String NDEF_MIME = "ndef-mime";
    private static final String NDEF_FORMATABLE = "ndef-formatable";
    private static final String TAG_DEFAULT = "tag";

    private static final String READER_MODE = "readerMode";
    private static final String DISABLE_READER_MODE = "disableReaderMode";

    // TagTechnology IsoDep, NfcA, NfcB, NfcV, NfcF, MifareClassic, MifareUltralight
    private static final String CONNECT = "connect";
    private static final String CLOSE = "close";
    private static final String TRANSCEIVE = "transceive";

    private static final String NFC_TAP_DEVICE = "nfc-tap-device";
    private static final String PREF_ENABLE_TAP_DEVICE_DISCOVERY = "EnableNFCTapDeviceDiscovery";
    private static final String PREF_TAP_DEVICE_MIME_TYPE = "NFCTapDeviceMimeType";
    private static final String PREF_ENABLE_NFC_PAIRING = "EnableNFCPairing";
    private static final String PREF_ENABLE_ENCRYPTION_WITH_NFC = "EnableEncryptionWithNFC";
    private static final String PREF_NFC_PAIRING_DONE_TOAST_MESSAGE = "NFCParingDoneToastMessage";
    private static final String REGISTER_NFC_TAP_DEVICE = "registerTapDevice";

//    @Nullable
//    private TagTechnology tagTechnology = null;
//    private Class<?> tagTechnologyClass;

    private static final String CHANNEL = "channel";

    private static final String STATUS_NFC_OK = "NFC_OK";
    private static final String STATUS_NO_NFC = "NO_NFC";
    private static final String STATUS_NFC_DISABLED = "NFC_DISABLED";
    private static final String STATUS_NDEF_PUSH_DISABLED = "NDEF_PUSH_DISABLED";

    private static final String TAG = "NfcPlugin";
    private final List<IntentFilter> intentFilters = new ArrayList<>();
    private final ArrayList<String[]> techLists = new ArrayList<>();

    private NdefMessage p2pMessage = null;
    private PendingIntent pendingIntent = null;

    private Intent savedIntent = null;

    private CallbackContext readerModeCallback;
    @Nullable
    private CallbackContext channelCallback;
    private CallbackContext shareTagCallback;
    private CallbackContext handoverCallback;

    @Nullable
    private NFCProtocol nfcProtocol;
    @Nullable
    private IoTizeDevice mLastTapDiscovered;
    @Nullable
    private Intent mLastTapDiscoveredIntent;

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {

        Log.d(TAG, "execute " + action);

        // showSettings can be called if NFC is disabled
        // might want to skip this if NO_NFC
        if (action.equalsIgnoreCase(SHOW_SETTINGS)) {
            showSettings(callbackContext);
            return true;
        }

        // the channel is set up when the plugin starts
        if (action.equalsIgnoreCase(CHANNEL)) {
            channelCallback = callbackContext;
            return true; // short circuit
        }

        // allow reader mode to be disabled even if nfc is disabled
        if (action.equalsIgnoreCase(DISABLE_READER_MODE)) {
            disableReaderMode(callbackContext);
            return true; // short circuit
        }

        if (!getNfcStatus().equals(STATUS_NFC_OK)) {
            callbackContext.error(getNfcStatus());
            return true; // short circuit
        }

        createPendingIntent();

        if (action.equalsIgnoreCase(READER_MODE)) {
            int flags = data.getInt(0);
            readerMode(flags, callbackContext);

        } else if (action.equalsIgnoreCase(REGISTER_MIME_TYPE)) {
            registerMimeType(data, callbackContext);
        } else if (action.equalsIgnoreCase(REGISTER_NFC_TAP_DEVICE)) {
//            JSONObject jsonStringOptions = data.getJSONObject(0);
            registerTapDevice(callbackContext);
        } else if (action.equalsIgnoreCase(REMOVE_MIME_TYPE)) {
            removeMimeType(data, callbackContext);

        } else if (action.equalsIgnoreCase(REGISTER_NDEF)) {
            registerNdef(callbackContext);
        } else if (action.equalsIgnoreCase(REMOVE_NDEF)) {
            removeNdef(callbackContext);

        } else if (action.equalsIgnoreCase(REGISTER_NDEF_FORMATABLE)) {
            registerNdefFormatable(callbackContext);

        } else if (action.equals(REGISTER_DEFAULT_TAG)) {
            registerDefaultTag(callbackContext);

        } else if (action.equals(REMOVE_DEFAULT_TAG)) {
            removeDefaultTag(callbackContext);

        } else if (action.equalsIgnoreCase(WRITE_TAG)) {
            writeTag(data, callbackContext);

        } else if (action.equalsIgnoreCase(MAKE_READ_ONLY)) {
            makeReadOnly(callbackContext);

        } else if (action.equalsIgnoreCase(ERASE_TAG)) {
            eraseTag(callbackContext);

        } else if (action.equalsIgnoreCase(SHARE_TAG)) {
            shareTag(data, callbackContext);

        } else if (action.equalsIgnoreCase(UNSHARE_TAG)) {
            unshareTag(callbackContext);

        } else if (action.equalsIgnoreCase(HANDOVER)) {
            handover(data, callbackContext);

        } else if (action.equalsIgnoreCase(STOP_HANDOVER)) {
            stopHandover(callbackContext);

        } else if (action.equalsIgnoreCase(INIT)) {
            init(callbackContext);

        } else if (action.equalsIgnoreCase(ENABLED)) {
            // status is checked before every call
            // if code made it here, NFC is enabled
            callbackContext.success(STATUS_NFC_OK);

        } else if (action.equalsIgnoreCase(CONNECT)) {
            String tech = data.getString(0);
            int timeout = data.optInt(1, -1);
            connect(tech, timeout, callbackContext);

        } else if (action.equalsIgnoreCase(TRANSCEIVE)) {
            CordovaArgs args = new CordovaArgs(data); // execute is using the old signature with JSON data

            byte[] command = args.getArrayBuffer(0);
            transceive(command, callbackContext);

        } else if (action.equalsIgnoreCase(CLOSE)) {
            close(callbackContext);

        } else {
            // invalid action
            return false;
        }

        return true;
    }

    private String getNfcStatus() {
        NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());
        if (nfcAdapter == null) {
            return STATUS_NO_NFC;
        } else if (!nfcAdapter.isEnabled()) {
            return STATUS_NFC_DISABLED;
        } else {
            return STATUS_NFC_OK;
        }
    }

    private void readerMode(int flags, CallbackContext callbackContext) {
        Bundle extras = new Bundle(); // not used
        readerModeCallback = callbackContext;
        getActivity().runOnUiThread(() -> {
            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());
            nfcAdapter.enableReaderMode(getActivity(), callback, flags, extras);
        });

    }

    private void disableReaderMode(CallbackContext callbackContext) {
        getActivity().runOnUiThread(() -> {
            readerModeCallback = null;
            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());
            if (nfcAdapter != null) {
                nfcAdapter.disableReaderMode(getActivity());
            }
            callbackContext.success();
        });
    }

    private NfcAdapter.ReaderCallback callback = new NfcAdapter.ReaderCallback() {
        @Override
        public void onTagDiscovered(Tag tag) {

            JSONObject json;

            // If the tag supports Ndef, try and return an Ndef message
            List<String> techList = Arrays.asList(tag.getTechList());
            if (techList.contains(Ndef.class.getName())) {
                Ndef ndef = Ndef.get(tag);
                json = Util.ndefToJSON(ndef);
            } else {
                json = Util.tagToJSON(tag);
            }

            PluginResult result = new PluginResult(PluginResult.Status.OK, json);
            result.setKeepCallback(true);
            readerModeCallback.sendPluginResult(result);

        }
    };

    @NonNull
    private NFCIntentParser getIntentParser(Intent intent) {
        NFCIntentParser parser = new NFCIntentParser(intent);
        Tag tag = parser.getTag();
        if (tag == null) {
            Log.wtf(TAG, "Intent has a nfc tag null. Intent = " + intent);
            throw new IllegalArgumentException("NFC tag is null. Retry nfc tap ?");
        }
        return parser;
    }

    private IoTizeDevice createTapFromIntent(Intent intent) throws Exception {
        Context context = getActivity();
        NFCIntentParser parser = this.getIntentParser(intent);
        ProtocolFactory nfcProtocolFactory = new NFCProtocolFactory(parser.getTag());
        IoTizeDevice tap = IoTizeDevice.fromProtocol(nfcProtocolFactory.create(context));
        tap.connect();
        if (preferences.getBoolean(PREF_ENABLE_NFC_PAIRING, true)) {
            byte[] response = tap.nfcPairing();
        }
        if (preferences.getBoolean(PREF_ENABLE_ENCRYPTION_WITH_NFC, false)) {
            tap.encryption(true, true);
        }
        return tap;
    }

    /**
     * @param intent
     * @return true if nfc intent has been handld
     */
    private boolean onTapDeviceDiscoveredIntent(Intent intent) {
        try {
            Log.d(TAG, "creating tap device...");
            IoTizeDevice tap = this.createTapFromIntent(intent);
            mLastTapDiscovered = tap;
            mLastTapDiscoveredIntent = intent;
            String nfcPairingDoneUserFeedback = preferences.getString(PREF_NFC_PAIRING_DONE_TOAST_MESSAGE, "NFC pairing done!");
            if (nfcPairingDoneUserFeedback.length() > 0) {
                Activity activity = cordova.getActivity();
                if (activity != null) {
                    activity.runOnUiThread(() -> {
                        try {
                            Toast.makeText(activity, nfcPairingDoneUserFeedback, Toast.LENGTH_LONG).show();
                        } catch (Throwable err) {
                            Log.w(TAG, err.getMessage(), err);
                        }
                    });
                }
            }
            fireTapDeviceEvent(tap, intent);
            return true;
        } catch (Exception e) {
            Log.w(TAG, e.getMessage(), e);
            return false;
        }

    }

    private void registerDefaultTag(CallbackContext callbackContext) {
        addTagFilter();
        restartNfc();
        callbackContext.success();
    }

    private void removeDefaultTag(CallbackContext callbackContext) {
        removeTagFilter();
        restartNfc();
        callbackContext.success();
    }

    private void registerNdefFormatable(CallbackContext callbackContext) {
        addTechList(new String[]{NdefFormatable.class.getName()});
        restartNfc();
        callbackContext.success();
    }

    private void registerNdef(CallbackContext callbackContext) {
        addTechList(new String[]{Ndef.class.getName()});
        restartNfc();
        callbackContext.success();
    }

    private void removeNdef(CallbackContext callbackContext) {
        removeTechList(new String[]{Ndef.class.getName()});
        restartNfc();
        callbackContext.success();
    }

    private void unshareTag(CallbackContext callbackContext) {
        p2pMessage = null;
        stopNdefPush();
        shareTagCallback = null;
        callbackContext.success();
    }

    private void init(CallbackContext callbackContext) {
        Log.d(TAG, "Enabling plugin " + getIntent());

        startNfc();
        if (!recycledIntent()) {
            parseMessage();
        }
        callbackContext.success();
    }

    private void removeMimeType(JSONArray data, CallbackContext callbackContext) throws JSONException {
        String mimeType = data.getString(0);
        removeIntentFilter(mimeType);
        restartNfc();
        callbackContext.success();
    }

    private void registerMimeType(JSONArray data, CallbackContext callbackContext) throws JSONException {
        String mimeType = "";
        try {
            mimeType = data.getString(0);
            intentFilters.add(createIntentFilter(mimeType));
            restartNfc();
            callbackContext.success();
        } catch (MalformedMimeTypeException e) {
            callbackContext.error("Invalid MIME Type " + mimeType);
        }
    }

    private void registerTapDevice(CallbackContext callbackContext) throws JSONException {
        Log.d(TAG, "registerTapDevice");
        if (mLastTapDiscovered != null) {
            Log.d(TAG, "a tap was detected before function call registerTapDevice");
            fireTapDeviceEvent(mLastTapDiscovered, mLastTapDiscoveredIntent);
        }
        callbackContext.success();
    }

    private void initializeTapDeviceListener() {
        if (this.isTapDeviceDiscoveryEnabled()) {
            addTechList(new String[]{Ndef.class.getName()});
            String mimeType = getTapDeviceMimeType();
            try {
                if (mimeType != null) {
                    intentFilters.add(createIntentFilter(mimeType));
                }
            } catch (MalformedMimeTypeException e) {
                Log.e(TAG, "MalformedMimeTypeException " + e.getMessage(), e);
            }

        }

    }

    private String getTapDeviceMimeType() {
        return preferences.getString(PREF_TAP_DEVICE_MIME_TYPE, null);
    }

    private boolean isTapDeviceDiscoveryEnabled() {
        return preferences.getBoolean(PREF_ENABLE_TAP_DEVICE_DISCOVERY, false);
    }

    // Cheating and writing an empty record. We may actually be able to erase some tag types.
    private void eraseTag(CallbackContext callbackContext) {
        Tag tag = savedIntent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
        NdefRecord[] records = {
                new NdefRecord(NdefRecord.TNF_EMPTY, new byte[0], new byte[0], new byte[0])
        };
        writeNdefMessage(new NdefMessage(records), tag, callbackContext);
    }

    private void writeTag(JSONArray data, CallbackContext callbackContext) throws JSONException {
        if (getIntent() == null) {  // TODO remove this and handle LostTag
            callbackContext.error("Failed to write tag, received null intent");
        }

        Tag tag = savedIntent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
        NdefRecord[] records = Util.jsonToNdefRecords(data.getString(0));
        writeNdefMessage(new NdefMessage(records), tag, callbackContext);
    }

    private void writeNdefMessage(final NdefMessage message, final Tag tag,
                                  final CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                Ndef ndef = Ndef.get(tag);
                if (ndef != null) {
                    ndef.connect();

                    if (ndef.isWritable()) {
                        int size = message.toByteArray().length;
                        if (ndef.getMaxSize() < size) {
                            callbackContext.error("Tag capacity is " + ndef.getMaxSize() +
                                    " bytes, message is " + size + " bytes.");
                        } else {
                            ndef.writeNdefMessage(message);
                            callbackContext.success();
                        }
                    } else {
                        callbackContext.error("Tag is read only");
                    }
                    ndef.close();
                } else {
                    NdefFormatable formatable = NdefFormatable.get(tag);
                    if (formatable != null) {
                        formatable.connect();
                        formatable.format(message);
                        callbackContext.success();
                        formatable.close();
                    } else {
                        callbackContext.error("Tag doesn't support NDEF");
                    }
                }
            } catch (FormatException e) {
                callbackContext.error(e.getMessage());
            } catch (TagLostException e) {
                callbackContext.error(e.getMessage());
            } catch (IOException e) {
                callbackContext.error(e.getMessage());
            }
        });
    }

    private void makeReadOnly(final CallbackContext callbackContext) {

        if (getIntent() == null) { // Lost Tag
            callbackContext.error("Failed to make tag read only, received null intent");
            return;
        }

        final Tag tag = savedIntent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
        if (tag == null) {
            callbackContext.error("Failed to make tag read only, tag is null");
            return;
        }

        cordova.getThreadPool().execute(() -> {
            boolean success = false;
            String message = "Could not make tag read only";

            Ndef ndef = Ndef.get(tag);

            try {
                if (ndef != null) {

                    ndef.connect();

                    if (!ndef.isWritable()) {
                        message = "Tag is not writable";
                    } else if (ndef.canMakeReadOnly()) {
                        success = ndef.makeReadOnly();
                    } else {
                        message = "Tag can not be made read only";
                    }

                } else {
                    message = "Tag is not NDEF";
                }

            } catch (IOException e) {
                Log.e(TAG, "Failed to make tag read only", e);
                if (e.getMessage() != null) {
                    message = e.getMessage();
                } else {
                    message = e.toString();
                }
            }

            if (success) {
                callbackContext.success();
            } else {
                callbackContext.error(message);
            }
        });
    }

    private void shareTag(JSONArray data, CallbackContext callbackContext) throws JSONException {
        NdefRecord[] records = Util.jsonToNdefRecords(data.getString(0));
        this.p2pMessage = new NdefMessage(records);

        startNdefPush(callbackContext);
    }

    // setBeamPushUris
    // Every Uri you provide must have either scheme 'file' or scheme 'content'.
    // Note that this takes priority over setNdefPush
    //
    // See http://developer.android.com/reference/android/nfc/NfcAdapter.html#setBeamPushUris(android.net.Uri[],%20android.app.Activity)
    private void handover(JSONArray data, CallbackContext callbackContext) throws JSONException {

        Uri[] uri = new Uri[data.length()];

        for (int i = 0; i < data.length(); i++) {
            uri[i] = Uri.parse(data.getString(i));
        }

        startNdefBeam(callbackContext, uri);
    }

    private void stopHandover(CallbackContext callbackContext) {
        stopNdefBeam();
        handoverCallback = null;
        callbackContext.success();
    }

    private void showSettings(CallbackContext callbackContext) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
            Intent intent = new Intent(android.provider.Settings.ACTION_NFC_SETTINGS);
            getActivity().startActivity(intent);
        } else {
            Intent intent = new Intent(android.provider.Settings.ACTION_WIRELESS_SETTINGS);
            getActivity().startActivity(intent);
        }
        callbackContext.success();
    }

    private void createPendingIntent() {
        if (pendingIntent == null) {
            Activity activity = getActivity();
            Intent intent = new Intent(activity, activity.getClass());
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP | Intent.FLAG_ACTIVITY_CLEAR_TOP);
            pendingIntent = PendingIntent.getActivity(activity, 0, intent, 0);
        }
    }

    private void addTechList(String[] list) {
        this.addTechFilter();
        this.addToTechList(list);
    }

    private void removeTechList(String[] list) {
        this.removeTechFilter();
        this.removeFromTechList(list);
    }

    private void addTechFilter() {
        intentFilters.add(new IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED));
    }

    private void removeTechFilter() {
        Iterator<IntentFilter> iterator = intentFilters.iterator();
        while (iterator.hasNext()) {
            IntentFilter intentFilter = iterator.next();
            if (NfcAdapter.ACTION_TECH_DISCOVERED.equals(intentFilter.getAction(0))) {
                iterator.remove();
            }
        }
    }

    private void addTagFilter() {
        intentFilters.add(new IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED));
    }

    private void removeTagFilter() {
        Iterator<IntentFilter> iterator = intentFilters.iterator();
        while (iterator.hasNext()) {
            IntentFilter intentFilter = iterator.next();
            if (NfcAdapter.ACTION_TAG_DISCOVERED.equals(intentFilter.getAction(0))) {
                iterator.remove();
            }
        }
    }

    private void restartNfc() {
        stopNfc();
        startNfc();
    }

    private void startNfc() {
        createPendingIntent(); // onResume can call startNfc before execute

        getActivity().runOnUiThread(() -> {
            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter != null && !getActivity().isFinishing()) {
                try {
                    IntentFilter[] intentFilters = getIntentFilters();
                    String[][] techLists = getTechLists();
                    // don't start NFC unless some intent filters or tech lists have been added,
                    // because empty lists act as wildcards and receives ALL scan events
                    if (intentFilters.length > 0 || techLists.length > 0) {
                        nfcAdapter.enableForegroundDispatch(getActivity(), getPendingIntent(), intentFilters, techLists);
                    }

                    if (p2pMessage != null) {
                        nfcAdapter.setNdefPushMessage(p2pMessage, getActivity());
                    }
                } catch (IllegalStateException e) {
                    // issue 110 - user exits app with home button while nfc is initializing
                    Log.w(TAG, "Illegal State Exception starting NFC. Assuming application is terminating.");
                }

            }
        });
    }

    private void stopNfc() {
        Log.d(TAG, "stopNfc");
        getActivity().runOnUiThread(() -> {

            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter != null) {
                try {
                    nfcAdapter.disableForegroundDispatch(getActivity());
                } catch (IllegalStateException e) {
                    // issue 125 - user exits app with back button while nfc
                    Log.w(TAG, "Illegal State Exception stopping NFC. Assuming application is terminating.");
                }
            }
        });
    }

    private void startNdefBeam(final CallbackContext callbackContext, final Uri[] uris) {
        getActivity().runOnUiThread(() -> {

            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter == null) {
                callbackContext.error(STATUS_NO_NFC);
            } else if (!nfcAdapter.isNdefPushEnabled()) {
                callbackContext.error(STATUS_NDEF_PUSH_DISABLED);
            } else {
                nfcAdapter.setOnNdefPushCompleteCallback(NfcPlugin.this, getActivity());
                try {
                    nfcAdapter.setBeamPushUris(uris, getActivity());

                    PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                    result.setKeepCallback(true);
                    handoverCallback = callbackContext;
                    callbackContext.sendPluginResult(result);

                } catch (IllegalArgumentException e) {
                    callbackContext.error(e.getMessage());
                }
            }
        });
    }

    private void startNdefPush(final CallbackContext callbackContext) {
        getActivity().runOnUiThread(() -> {

            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter == null) {
                callbackContext.error(STATUS_NO_NFC);
            } else if (!nfcAdapter.isNdefPushEnabled()) {
                callbackContext.error(STATUS_NDEF_PUSH_DISABLED);
            } else {
                nfcAdapter.setNdefPushMessage(p2pMessage, getActivity());
                nfcAdapter.setOnNdefPushCompleteCallback(NfcPlugin.this, getActivity());

                PluginResult result = new PluginResult(PluginResult.Status.NO_RESULT);
                result.setKeepCallback(true);
                shareTagCallback = callbackContext;
                callbackContext.sendPluginResult(result);
            }
        });
    }

    private void stopNdefPush() {
        getActivity().runOnUiThread(() -> {

            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter != null) {
                nfcAdapter.setNdefPushMessage(null, getActivity());
            }

        });
    }

    private void stopNdefBeam() {
        getActivity().runOnUiThread(() -> {

            NfcAdapter nfcAdapter = NfcAdapter.getDefaultAdapter(getActivity());

            if (nfcAdapter != null) {
                nfcAdapter.setBeamPushUris(null, getActivity());
            }

        });
    }

    private void addToTechList(String[] techs) {
        techLists.add(techs);
    }

    private void removeFromTechList(String[] techs) {
        Iterator<String[]> iterator = techLists.iterator();
        while (iterator.hasNext()) {
            String[] list = iterator.next();
            if (Arrays.equals(list, techs)) {
                iterator.remove();
            }
        }
    }

    private void removeIntentFilter(String mimeType) {
        Iterator<IntentFilter> iterator = intentFilters.iterator();
        while (iterator.hasNext()) {
            IntentFilter intentFilter = iterator.next();
            String mt = intentFilter.getDataType(0);
            if (mimeType.equals(mt)) {
                iterator.remove();
            }
        }
    }

    private IntentFilter createIntentFilter(String mimeType) throws MalformedMimeTypeException {
        IntentFilter intentFilter = new IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED);
        intentFilter.addDataType(mimeType);
        return intentFilter;
    }

    private PendingIntent getPendingIntent() {
        return pendingIntent;
    }

    private IntentFilter[] getIntentFilters() {
        return intentFilters.toArray(new IntentFilter[intentFilters.size()]);
    }

    private String[][] getTechLists() {
        //noinspection ToArrayCallWithZeroLengthArrayArgument
        return techLists.toArray(new String[0][0]);
    }

    private void parseMessage() {
        cordova.getThreadPool().execute(() -> {
            Log.d(TAG, "parseMessage " + getIntent());
            Intent intent = getIntent();
            String action = intent.getAction();
            Log.d(TAG, "action " + action);
            if (action == null) {
                return;
            }

            Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
            Parcelable[] messages = intent.getParcelableArrayExtra((NfcAdapter.EXTRA_NDEF_MESSAGES));

            if (isTapDeviceDiscoveryEnabled() && tag != null) {
                onTapDeviceDiscoveredIntent(intent);
            }

            if (action.equals(NfcAdapter.ACTION_NDEF_DISCOVERED)) {
                Ndef ndef = Ndef.get(tag);
                fireNdefEvent(NDEF_MIME, ndef, messages);
                Log.d(TAG, "Saving Intent for connect" + intent);
                savedIntent = intent;

            } else if (action.equals(NfcAdapter.ACTION_TECH_DISCOVERED)) {
                for (String tagTech : tag.getTechList()) {
                    Log.d(TAG, tagTech);
                    if (tagTech.equals(NdefFormatable.class.getName())) {
                        fireNdefFormatableEvent(tag);
                    } else if (tagTech.equals(Ndef.class.getName())) { //
                        Ndef ndef = Ndef.get(tag);
                        fireNdefEvent(NDEF, ndef, messages);
                    }
                }
            }

            if (action.equals(NfcAdapter.ACTION_TAG_DISCOVERED)) {
                fireTagEvent(tag);
            }

            setIntent(new Intent());
        });
    }

    private boolean notifyWhenNfcPairingDone() {
        return true; // TODO
    }

    private void sendEvent(String type, JSONObject tag, JSONObject tap) {
        try {
            JSONObject event = new JSONObject();
            event.put("type", type);       // TAG_DEFAULT, NDEF, NDEF_MIME, NDEF_FORMATABLE
            event.put("tag", tag);         // JSON representing the NFC tag and NDEF messages
            event.put("tap", tap);
            sendEvent(event);
        } catch (JSONException e) {
            Log.e(TAG, "Error sending NFC event through the channel", e);
        }

    }

    private void sendEvent(String type, JSONObject tag) {
        try {
            JSONObject event = new JSONObject();
            event.put("type", type);       // TAG_DEFAULT, NDEF, NDEF_MIME, NDEF_FORMATABLE
            event.put("tag", tag);         // JSON representing the NFC tag and NDEF messages
            sendEvent(event);
        } catch (JSONException e) {
            Log.e(TAG, "Error sending NFC event through the channel", e);
        }
    }

    // Send the event data through a channel so the JavaScript side can fire the event
    private void sendEvent(JSONObject event) {
        PluginResult result = new PluginResult(PluginResult.Status.OK, event);
        result.setKeepCallback(true);
        if (channelCallback != null) {
            channelCallback.sendPluginResult(result);
        }
    }

    private void fireNdefEvent(String type, Ndef ndef, Parcelable[] messages) {
        JSONObject json = buildNdefJSON(ndef, messages);
        sendEvent(type, json);
    }

    private void fireTapDeviceEvent(IoTizeDevice tap, Intent intent) {
        try {
            Log.d(TAG, "fireTapDeviceEvent " + tap);
            Tag tag = intent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
            Ndef ndef = Ndef.get(tag);
            Parcelable[] messages = intent.getParcelableArrayExtra((NfcAdapter.EXTRA_NDEF_MESSAGES));

            sendEvent(NFC_TAP_DEVICE, buildNdefJSON(ndef, messages), buildTapJSON(tap));
        } catch (JSONException e) {
            Log.e(TAG, e.getMessage(), e);
        }
    }

    private JSONObject buildTapJSON(IoTizeDevice tap) throws JSONException {
        JSONObject tapInfo = new JSONObject();
        tapInfo.put("nfcPairingDone", true); // TODO
        JSONObject encryptionJSON = new JSONObject();
        boolean encryptionEnabled = false;
        if (tap.isEncryptionEnabled()) {
            EncryptionAlgo encryptionAlgo = tap.getClient().getEncryptionAlgo();
            if (encryptionAlgo != null) {
                encryptionEnabled = true;
                encryptionJSON.put("enabled", true);
                JSONObject keysOptions = new JSONObject();
                keysOptions.put("sessionKey", Util.byteArrayToJSON(encryptionAlgo.getKey()));
                int frameCounter = 0;
                try {
                    // TODO change with frameCounter
                    TapClient client = tap.getClient();
                    Field field = client.getClass().getDeclaredField("frameCounter");
                    field.setAccessible(true);
                    frameCounter = (int) field.get(client);
                } catch (NoSuchFieldException e) {
                    Log.w(TAG, e.getMessage(), e);
                } catch (IllegalAccessException e) {
                    Log.w(TAG, e.getMessage(), e);
                }
                keysOptions.put("sessionKeyHex", Helper.ByteArrayToHexString(encryptionAlgo.getKey()));
//            keysOptions.put("ivEncode", Util.byteArrayToJSON(());
//            keysOptions.put("ivDecode", Util.byteArrayToJSON(());

                encryptionJSON.put("keys", keysOptions);
                encryptionJSON.put("frameCounter", frameCounter);
            }
        }
        encryptionJSON.put("enabled", encryptionEnabled);
        tapInfo.put("encryption", encryptionJSON);
        return tapInfo;
    }

    private void fireNdefFormatableEvent(Tag tag) {
        sendEvent(NDEF_FORMATABLE, Util.tagToJSON(tag));
    }

    private void fireTagEvent(Tag tag) {
        sendEvent(TAG_DEFAULT, Util.tagToJSON(tag));
    }

    private JSONObject buildNdefJSON(Ndef ndef, Parcelable[] messages) {

        JSONObject json = Util.ndefToJSON(ndef);

        // ndef is null for peer-to-peer
        // ndef and messages are null for ndef format-able
        if (ndef == null && messages != null) {

            try {

                if (messages.length > 0) {
                    NdefMessage message = (NdefMessage) messages[0];
                    json.put("ndefMessage", Util.messageToJSON(message));
                    // guessing type, would prefer a more definitive way to determine type
                    json.put("type", "NDEF Push Protocol");
                }

                if (messages.length > 1) {
                    Log.wtf(TAG, "Expected one ndefMessage but found " + messages.length);
                }

            } catch (JSONException e) {
                // shouldn't happen
                Log.e(Util.TAG, "Failed to convert ndefMessage into json", e);
            }
        }
        return json;
    }

    private boolean recycledIntent() { // TODO this is a kludge, find real solution

        int flags = getIntent().getFlags();
        if ((flags & Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) {
            Log.i(TAG, "Launched from history, killing recycled intent");
            setIntent(new Intent());
            return true;
        }
        return false;
    }

    @Override
    public void onStart() {
        super.onStart();
        this.initializeTapDeviceListener();
    }

    @Override
    public void onPause(boolean multitasking) {
        Log.d(TAG, "onPause " + getIntent());
        super.onPause(multitasking);
        if (multitasking) {
            // nfc can't run in background
            stopNfc();
        }
    }

    @Override
    public void onResume(boolean multitasking) {
        Log.d(TAG, "onResume " + getIntent());
        super.onResume(multitasking);
        startNfc();
    }

    @Override
    public void onNewIntent(Intent intent) {
        Log.d(TAG, "onNewIntent " + intent);
        super.onNewIntent(intent);
        setIntent(intent);
        savedIntent = intent;
        parseMessage();
    }

    private Activity getActivity() {
        return this.cordova.getActivity();
    }

    private Intent getIntent() {
        return getActivity().getIntent();
    }

    private void setIntent(Intent intent) {
        getActivity().setIntent(intent);
    }

    @Override
    public void onNdefPushComplete(NfcEvent event) {

        // handover (beam) take precedence over share tag (ndef push)
        if (handoverCallback != null) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, "Beamed Message to Peer");
            result.setKeepCallback(true);
            handoverCallback.sendPluginResult(result);
        } else if (shareTagCallback != null) {
            PluginResult result = new PluginResult(PluginResult.Status.OK, "Shared Message with Peer");
            result.setKeepCallback(true);
            shareTagCallback.sendPluginResult(result);
        }

    }

    /**
     * Enable I/O operations to the tag from this TagTechnology object.
     * *
     *
     * @param tech            TagTechnology class name e.g. 'android.nfc.tech.IsoDep' or 'android.nfc.tech.NfcV'
     * @param timeout         tag timeout
     * @param callbackContext Cordova callback context
     */
    private void connect(final String tech, final int timeout,
                         final CallbackContext callbackContext) {
        this.cordova.getThreadPool().execute(() -> {
            try {

                Tag tag = getIntent().getParcelableExtra(NfcAdapter.EXTRA_TAG);
                if (tag == null) {
                    tag = savedIntent.getParcelableExtra(NfcAdapter.EXTRA_TAG);
                }

                if (tag == null) {
                    Log.e(TAG, "No Tag");
                    callbackContext.error("No Tag");
                    return;
                }

                // get technologies supported by this tag
                List<String> techList = Arrays.asList(tag.getTechList());
                if (techList.contains(tech)) {
                    // use reflection to call the static function Tech.get(tag)
//                    tagTechnologyClass = Class.forName(tech);
                    nfcProtocol = NFCProtocol.create(tag);
//                    Method method = tagTechnologyClass.getMethod("get", Tag.class);
//                    tagTechnology = (TagTechnology) method.invoke(null, tag);
                }

                if (nfcProtocol == null) {
                    callbackContext.error("Tag does not support " + tech);
                    return;
                }

                nfcProtocol.connect();
                setTimeout(timeout);
                Log.d(TAG, "NFC Connection successful");
                callbackContext.success();
            } catch (IOException ex) {
                Log.e(TAG, "Tag connection failed", ex);
                callbackContext.error("Tag connection failed");
            } catch (Throwable e) {
                Log.e(TAG, e.getMessage(), e);
                callbackContext.error(e.getMessage());
            }
        });
    }

    private void setTimeout(int timeout) {
        if (timeout < 0) {
            return;
        }
        if (nfcProtocol != null) {
            nfcProtocol.getConfiguration().connectionTimeoutMillis = timeout;
        }
    }

    /**
     * Disable I/O operations to the tag from this TagTechnology object, and release resources.
     *
     * @param callbackContext Cordova callback context
     */
    private void close(CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (nfcProtocol != null && nfcProtocol.isConnected()) {
                    nfcProtocol.disconnect();
                }
                callbackContext.success();

            } catch (Exception ex) {
                Log.e(TAG, "Error closing nfc connection", ex);
                callbackContext.error("Error closing nfc connection " + ex.getLocalizedMessage());
            }
        });
    }

    /**
     * Send raw commands to the tag and receive the response.
     *
     * @param data            byte[] command to be passed to the tag
     * @param callbackContext Cordova callback context
     */
    private void transceive(final byte[] data, final CallbackContext callbackContext) {
        cordova.getThreadPool().execute(() -> {
            try {
                if (nfcProtocol == null) {
                    Log.e(TAG, "No Tech");
                    callbackContext.error("No Tech");
                    return;
                }
                if (!nfcProtocol.isConnected()) {
                    Log.e(TAG, "Not connected");
                    callbackContext.error("Not connected");
                    return;
                }

                // Use reflection so we can support many tag types
                //Method transceiveMethod = tagTechnologyClass.getMethod("transceive", byte[].class);
//                @SuppressWarnings("PrimitiveArrayArgumentToVarargsMethod")
//                byte[] response = (byte[]) transceiveMethod.invoke(tagTechnology, data);
                byte[] response = nfcProtocol.send(data);
                callbackContext.success(Helper.ByteArrayToHexString(response));
            } catch (Exception e) {
                Log.e(TAG, e.getMessage(), e);
                callbackContext.error(e.getMessage());
            }
        });
    }

}
