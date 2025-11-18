package com.chariotsolutions.nfc.plugin;

import android.nfc.Tag;
import android.nfc.TagLostException;
import android.nfc.tech.NfcV;
import android.util.Log;

import com.iotize.android.communication.protocol.nfc.EHCtrlDyn;
import com.iotize.android.communication.protocol.nfc.MBCtrlDyn;
import com.iotize.android.communication.protocol.nfc.NfcCtrlResponse;
import com.iotize.android.core.util.Helper;
import com.iotize.android.communication.client.impl.protocol.ConnectionState;
import com.iotize.android.communication.client.impl.protocol.HostProtocol;
import com.iotize.android.communication.client.impl.protocol.exception.TimeOutException;

import java.io.IOException;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 *
 */
public class NFC5Protocol extends NFCProtocol {
    private static final String TAG = "NFC5Protocol";

    public static final byte STM_MANUFACTURER_CODE = (byte) 0x02;

    /*MB_CTRL_Dyn register address*/
    /**
     * dynamic register contains most of the information to understand the
     * state of the FTM (Fast transfer mode)
     * MB_CTRL_DYN
     */
    public static final byte MB_CTRL_DYN = (byte) 0x0D;
    /**
     * ENERGY HARVESTING control register
     * EH_CTRL_DYN
     */
    public static final byte EH_CTRL_DYN = (byte) 0x02;

    /*ST25 commands*/
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_WRITE_MB_MSG = (byte) 0xAA;
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG_LENGTH = (byte) 0xAB;
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG = (byte) 0xAC;

    public static final byte ISO15693_CUSTOM_ST_CMD_READ_CONFIG = (byte) 0xA0;
    public static final byte ISO15693_CUSTOM_ST_CMD_WRITE_CONFIG = (byte) 0xA1;
    public static final byte ISO15693_CUSTOM_ST_CMD_READ_DYN_CONFIG = (byte) 0xAD;
    public static final byte ISO15693_CUSTOM_ST_CMD_WRITE_DYN_CONFIG = (byte) 0xAE;

    /*fast st25 commande*/
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_FAST_WRITE_MB_MSG = (byte) 0xCA;
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_FAST_READ_MB_MSG = (byte) 0xCC;
    public static final byte ISO15693_CUSTOM_ST25DV_CMD_FAST_READ_MB_MSG_LENGTH = (byte) 0xCB;
    public static final byte ISO15693_CUSTOM_ST_CMD_FAST_READ_DYN_CONFIG = (byte) 0xCD;
    public static final byte ISO15693_CUSTOM_ST_CMD_FAST_WRITE_DYN_CONFIG = (byte) 0xCE;

    public static final byte FLAG_SELECTED_STATE_HR = (byte) 0x12;
    public static final byte FLAG_HIGH_DATA_RATE = (byte) 0x02;
    public static final byte ENABLE_MB = (byte) 0x01;
    public static final byte DISABLE_MB = (byte) 0x00;

    /*Size of the header in iso 15693 without the UID*/
    protected static final int ISO15693_CUSTOM_ST_HEADER_SIZE = 3;

    private static final int DELAY = 50;                            // timeout resolution in ms
    private static final int TIMEOUT_NFC5 = 2000;    // timeout value in ms
    private static final int NB_MAX_RETRY = 3;
    private static final int MAX_CONNECTION_RETRY = 3;

    @NonNull
    private NfcV nfcTag;

    private byte[] lastMessage = null;
    private long responsePollingDelay = 50;
    private long beforePollingDelay = 50;

    public NFC5Protocol(@NonNull Tag tag) {
        super(tag);
        nfcTag = NfcV.get(tag);
    }

    @NonNull
    public byte[] tranceiveNFC(@NonNull byte[] command) throws IOException, TimeOutException, InterruptedException {
        return transceiveISO15693(command);
    }

    @Override
    public void _connect() throws IOException {
        int tryCount = 0;
        do {
            try {
                Log.d(TAG, "Connection try n°" + tryCount + "...");
                tryCount++;
                _connectNoRetry();
                return;
            } catch (Exception err) {
                if (tryCount >= MAX_CONNECTION_RETRY) {
                    throw err;
                }
                Log.d(TAG, "Connection try n°" + tryCount + " failed with error: " + err.getMessage());
            }
        } while (true);
    }

    private void _connectNoRetry() throws IOException {
        try {
            this.closeTag();
            this.connectNfcTag();
            Log.d(TAG, "_connect SUCCESSFUL");
        } catch (IOException ex) {
            Log.e(TAG, "Error during nfc connection", ex);
            throw new TagLostException("Cannot connect to this nfc tag." + (ex.getMessage() != null ? ex.getMessage() : ""));
        }
    }

    @Override
    public void _disconnect() {
        this.closeTag();
    }

    private void closeTag() {
        try {
            Log.d(TAG, "Closing tag");
            nfcTag.close();
        } catch (Throwable err) {
            Log.d(TAG, "Cannot close tag properly: " + err.getMessage());
        } // Ignoring error. Close to prevent error {@link IllegalStateException} "close other technology first"
    }

    @Override
    public void write(byte[] message) throws Exception {
        int tryCount = 0;
        do {
            try {
                tryCount++;
                Log.v(TAG, "Sending (try n° " + tryCount + ") " + message.length + " bytes... 0x" + Helper.ByteArrayToHexString(message));
                lastMessage = tranceiveNFC(message);
                Log.d(TAG, "Sent " + message.length + "bytes OK");
                return;
            } catch (TagLostException | SecurityException ex) {
                this.disconnectAndNotify();
                throw new Exception("NFC tag lost (probably NFC tag is not in range anymore)");
            } catch (TimeOutException ex) {
                if (tryCount >= NB_MAX_RETRY) {
                    this.disconnectAndNotify();
                    throw ex;
                } else {
                    Log.v(TAG, "Sending (try n° " + tryCount + ") " + message.length + " bytes failed with error: " + ex.getMessage());
                }
            }
        } while (true);
    }

    private void disconnectAndNotify() {
        setConnectionStatus(ConnectionState.DISCONNECTING);
        this._disconnect();
        setConnectionStatus(ConnectionState.DISCONNECTED);
    }


    @Override
    @NonNull
    public byte[] read() throws Exception {
        if (lastMessage == null) {
            lastMessage = new byte[]{};
        }
        Log.d(TAG, "Receive: 0x" + Helper.ByteArrayToHexString(lastMessage));
        return lastMessage;
    }

    @Override
    public void sendAsync(byte[] responseMessage, IOnEvent<byte[]> event) {

    }

    @Override
    public HostProtocol getType() {
        return HostProtocol.NFC;
    }


    /****ST FUNCTIONS **********************************************/

    public MBCtrlDyn readMBConfig() throws IOException {
        MBCtrlDyn mbCtrlDyn = new MBCtrlDyn(this.readDynConfig(MB_CTRL_DYN));
        Log.v(TAG, "readDynConfig => mbCtrlDyn " + mbCtrlDyn.toString());
        return mbCtrlDyn;
    }

    public EHCtrlDyn readEnergyHarvestingConfig() throws IOException {
        EHCtrlDyn ctrl = new EHCtrlDyn(this.readDynConfig(EH_CTRL_DYN));
        Log.v(TAG, "readEnergyHarvestingConfig => " + ctrl.toString());
        if (ctrl.hasFlag(EHCtrlDyn.Flags.EH_EN)) {
            this.beforePollingDelay = 70;
            this.responsePollingDelay = 50;
        } else {
            this.beforePollingDelay = 50;
            this.responsePollingDelay = 50;
        }
        return ctrl;
    }

    private NfcCtrlResponse transceiveCommand(byte cmd) throws IOException {
        return transceiveCommand(cmd, null);
    }

    private NfcCtrlResponse transceiveCommand(byte cmd, @Nullable byte[] cmdData) throws IOException {
        int headerSize = ISO15693_CUSTOM_ST_HEADER_SIZE;
        byte[] request = new byte[headerSize + (cmdData != null ? cmdData.length : 0)];

        request[0] = FLAG_HIGH_DATA_RATE;
        request[1] = cmd;
        request[2] = STM_MANUFACTURER_CODE;

        if (cmdData != null) {
            for (int i = 0; i < cmdData.length; i++){
                request[headerSize + i] = cmdData[i];
            }
        }
        try {
            byte[] response = nfcTag.transceive(request);
            return new NfcCtrlResponse(response);
        }
        catch (TagLostException e) {
            this.disconnectAndNotify();
            throw e;
        }
    }

    /**
     * Send a read dynamicClosing tag register command to the ST25
     *
     * @param configId : register RF address
     * @return register value or 0Fh if error
     * @throws IOException when I/O exception
     */
    @NonNull
    private byte readDynConfig(byte configId) throws IOException {
        NfcCtrlResponse response;
        int tryCount = 1;
        do {
            byte[] config = new byte[]{configId};
            response = transceiveCommand(ISO15693_CUSTOM_ST_CMD_READ_DYN_CONFIG, config);
            Log.v(TAG, "readDynConfig try n° " + tryCount + "; configId=" + configId + " => response: 0x" + Helper.ByteArrayToHexString(response.rawData()));
            if (response.isSuccessful()) {
                return response.getRegisterValue();
            }
            else {
                if (tryCount >= 3) {
                    // Will throw
                    response.successful();
                }
                tryCount++;
            }
        } while (true);
    }


    public int readMsgLength() throws IOException {
        NfcCtrlResponse response = transceiveCommand(ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG_LENGTH);
        response.successful();
        return response.body()[0] & 0xFF;
    }

    /**
     * Send a Write message command to the st25
     *
     * @param buffer to send
     * @return flag byte
     * @throws IOException when I/O exception
     */
    public NfcCtrlResponse writeMsg(byte[] buffer) throws IOException {
        return this.writeMsg(buffer.length, buffer);
    }

    /**
     * Send a Write message command to the st25
     *
     * @param sizeInBytes to send
     * @param buffer      to send
     * @return flag byte
     * @throws IOException when I/O exception
     */
    public NfcCtrlResponse writeMsg(int sizeInBytes, byte[] buffer) throws IOException {
        if (buffer.length < sizeInBytes) {
            throw new IllegalArgumentException("Cannot send " + sizeInBytes + " bytes. Buffer is too small");
        }
        if (sizeInBytes > 0xFF) {
            throw new IllegalArgumentException("NFC message is too big. Maximum size is " + 0xFF + " bytes but trying to write " + sizeInBytes + " bytes");
        }
        byte msgLength = (byte) ((sizeInBytes - 1) & 0xFF);
        byte[] cmdData =  new byte[1 + sizeInBytes];
        cmdData[0] = msgLength;
        System.arraycopy(buffer, 0, cmdData, 1, sizeInBytes);
        return transceiveCommand(
            ISO15693_CUSTOM_ST25DV_CMD_WRITE_MB_MSG,
            cmdData
        );
    }

    /**
     * Send a Read message command to the st25
     *
     * @param offset      position in received buffer to copy the messsage
     * @return flag byte + message
     * @throws IOException when I/O exception
     */
    @NonNull
    public byte[] readMsg(byte offset, int msgLength) throws IOException {
        NfcCtrlResponse response = transceiveCommand(
            ISO15693_CUSTOM_ST25DV_CMD_READ_MB_MSG,
            new byte[]{
                offset,
                (byte) (0xFF & msgLength)
            }
        );
        return response.body();
    }

    /**
     * Transceive method adapted for the ST25
     * <p>
     * #1: send a write command to the ST25
     * #2: poll on MB_CTRL register until host put a msg
     * #3: get the message length
     * #4: send a read command to the ST25
     *
     * @param data to send to the module
     * @return module response or null if error
     * @throws IOException      if it fails
     * @throws TimeOutException if it fails
     */
    @NonNull
    public byte[] transceiveISO15693(byte[] data) throws IOException, TimeOutException, InterruptedException {
        this._assertTagConnected();

        this.checkMailbox();

        this.writeWithRetry(data);

        // It seems that removing this initial delay not work properly with energy harvesting
        Thread.sleep(beforePollingDelay);
        this.pollMBControl();

        return this.readResponse();
    }

    private void _assertTagConnected() throws IOException {
        if (!this.nfcTag.isConnected()) {
            if (this.isConnected()) {
                this.connectNfcTag();
            } else {
                this.setConnectionStatus(ConnectionState.DISCONNECTED);
                throw new IOException("Tag is not connected");
            }
        }
    }

    private void connectNfcTag() throws IOException {
        Log.d(TAG, "Connecting NFC tag");
        try {
            nfcTag.connect();
            boolean isConnected = nfcTag.isConnected();
            Log.d(TAG, "is connected: " + isConnected);
        } catch (IOException err){
            if (err.getMessage() == null){
                throw new IOException("Cannot connect to NFC tag", err);
            }
            else {
                throw err;
            }
        }
        readEnergyHarvestingConfig();
    }

    private byte[] readResponse() throws TimeOutException, IOException, InterruptedException {
        int msgLength;
        byte offset = 0;
        int retryCount = 0;
        IOException lastReadError;
        do {
            try {
                //read message length
                msgLength = readMsgLength();
                if (msgLength < 0) {
                    throw new IllegalStateException("Received a negative message length: " + msgLength);
                }
                return readMsg(offset, msgLength);


            } catch (IOException err) {
                Log.d(TAG, "Attempt to read n°" + retryCount + 1 + " failed with error " + err.getMessage());
                lastReadError = err;
                retryCount++;
                Thread.sleep(DELAY);
            }
        }
        while (retryCount < NB_MAX_RETRY);

        throw lastReadError;
    }

    /**
     * poll MB_CTRL_Dyn register to see if answer is arrived
     *
     * @return register status when a message arrived
     * @throws IOException
     * @throws InterruptedException
     * @throws TimeOutException
     */
    private MBCtrlDyn pollMBControl() throws IOException, InterruptedException, TimeOutException {
        MBCtrlDyn ctrlRegister;

        long time = 0;

        long pollingDelay = this.responsePollingDelay;

        while (time < TIMEOUT_NFC5) {
            ctrlRegister = readMBConfig();
            if (ctrlRegister.hasFlag(MBCtrlDyn.Flags.HOST_PUT_MSG)) {
                return ctrlRegister;
            }
            Thread.sleep(pollingDelay);
            time += pollingDelay;
            pollingDelay = pollingDelay * 2;
        }

        throw new TimeOutException("NFC receive Timeout. Device did not response to request in given time (" + TIMEOUT_NFC5 + "ms)");
    }

    private void writeWithRetry(byte[] data) throws IOException, InterruptedException {
        int count = 0;
        NfcCtrlResponse response;
        do {
            response = writeMsg(data);
            if (response.isSuccessful()) {
                return;
            }
            count++;
            Log.d(TAG, "retry n°" + count + " nfc write " + data.length + " bytes");
            Thread.sleep(DELAY);
        }
        while (count < NB_MAX_RETRY);

        throw new IOException("NFC tag write failed. " + (response != null ? "Unexpected NFC response: " + Helper.ByteArrayToHexString(response.rawData()) : ""));
    }

    /**
     * check if mailbox is enable, if not, reset mailbox
     * => check that fast transfer mode is on ?
     *
     * @throws IOException
     */
    private void checkMailbox() throws IOException {
        MBCtrlDyn status = readMBConfig();

        if (!status.hasFlag(MBCtrlDyn.Flags.MB_ENABLED) ||
                status.hasFlag(MBCtrlDyn.Flags.RF_CURRENT_MSG) ||
                        status.hasFlag(MBCtrlDyn.Flags.HOST_CURRENT_MSG)) {
            Log.d(TAG, "checkMailbox: clearing msgbox...");
            writeDynConfig(MB_CTRL_DYN, DISABLE_MB, FLAG_HIGH_DATA_RATE);
            writeDynConfig(MB_CTRL_DYN, ENABLE_MB, FLAG_HIGH_DATA_RATE);
            status = readMBConfig();
            if (!status.hasFlag(MBCtrlDyn.Flags.MB_ENABLED)){
                throw new IOException("Cannot enabled NFC communication");
            }
        }
//        if ((status != 0x41) && (status != (byte) 0x81) && (status != (byte) 0x1)) {
//            writeDynConfig(MB_CTRL_DYN, DISABLE_MB, FLAG_HIGH_DATA_RATE);
//            writeDynConfig(MB_CTRL_DYN, ENABLE_MB, FLAG_HIGH_DATA_RATE);
//            Log.d(TAG, "checkMailbox: clear msgbox");
//        }
    }


    /**
     * Write in dyn registers of the ST25
     *
     * @param configId          : command corresponding to register
     * @param newAttributeValue : value to set to the register
     * @param flag              flag
     * @return the response
     * @throws IOException if fails
     */
    public byte[] writeDynConfig(byte configId, byte newAttributeValue, byte flag) throws IOException {
        byte[] request;
        int header_size;

        header_size = ISO15693_CUSTOM_ST_HEADER_SIZE;
        request = new byte[header_size + 1 + 1]; // +1 for configId and +1 for newAttributeValue

        request[0] = flag;
        request[1] = ISO15693_CUSTOM_ST_CMD_WRITE_DYN_CONFIG;
        request[2] = STM_MANUFACTURER_CODE;

        //if (uidNeeded(flag)) addUidToFrame(request, ISO15693_CUSTOM_ST_HEADER_SIZE, uid);

        request[header_size] = configId;
        request[header_size + 1] = newAttributeValue;

        return nfcTag.transceive(request);
    }

    public String toString() {
        return "NFC5Protocol{" +
                "nfcTag=" + nfcTag +
                "; state=" + this.getConnectionStatus() +
                '}';
    }

}
