package com.chariotsolutions.nfc.plugin;

import android.nfc.Tag;
import android.nfc.tech.IsoDep;

import com.iotize.android.core.util.SynchronizeHelper;
import com.iotize.android.communication.client.impl.protocol.HostProtocol;

import java.io.IOException;

/**
 *
 */
public class NFC4Protocol extends NFCProtocol {

    private static final long DEFAULT_READ_TIMEOUT = 2000;
    private final IsoDep nfcTag;
    private byte[] lastMessage;

    public NFC4Protocol(Tag tag) {
        super(tag);
        nfcTag = IsoDep.get(tag);
    }


    @Override
    public void _connect() throws IOException {
        if (nfcTag.isConnected()) {
            nfcTag.connect();
        }
    }

    @Override
    public void _disconnect() throws Exception {
        nfcTag.close();
    }

    @Override
    public void write(byte[] message) throws Exception {
        byte[] payload = nfcTag.transceive(message);
        lastMessage = payload;
    }

    @Override
    public byte[] read() throws Exception {
        SynchronizeHelper.waitForNotNull(lastMessage, DEFAULT_READ_TIMEOUT);
        return lastMessage;
    }

    @Override
    public void sendAsync(byte[] responseMessage, IOnEvent<byte[]> event) {

    }

    @Override
    public HostProtocol getType() {
        return HostProtocol.NFC;
    }

    @Override
    public String toString() {
        return "NFC4Protocol{" +
                "nfcTag=" + nfcTag +
                '}';
    }

//    @Override
//    public boolean isSameTag(Tag tag) {
//        if (tag == null){
//            return false;
//        }
//        IsoDep isoDepTag = IsoDep.get(tag);
//        if (isoDepTag == null){
//            return false;
//        }
//        return this.nfcTag.equals(isoDepTag);
//    }
}
