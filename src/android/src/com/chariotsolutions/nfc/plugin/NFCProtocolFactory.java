package com.chariotsolutions.nfc.plugin;

import android.content.Context;
import android.nfc.Tag;
import android.os.Parcel;
import android.os.Parcelable;

import com.iotize.android.communication.client.impl.protocol.ProtocolFactory;
import com.iotize.android.communication.client.impl.protocol.HostProtocol;
import com.iotize.android.core.util.Helper;

/**
 *
 */

public class NFCProtocolFactory implements ProtocolFactory<NFCProtocol> {

    protected Tag tag;

    public NFCProtocolFactory(Tag nfcTag) {
        this.tag = nfcTag;
    }

    protected NFCProtocolFactory(Parcel in) {
        tag = in.readParcelable(Tag.class.getClassLoader());
    }

    public static final Parcelable.Creator<NFCProtocolFactory> CREATOR = new Parcelable.Creator<NFCProtocolFactory>() {
        @Override
        public NFCProtocolFactory createFromParcel(Parcel in) {
            return new NFCProtocolFactory(in);
        }

        @Override
        public NFCProtocolFactory[] newArray(int size) {
            return new NFCProtocolFactory[size];
        }
    };

    @Override
    public NFCProtocol create(Context context) {
        return NFCProtocol.create(tag);
    }

    @Override
    public HostProtocol getType() {
        return HostProtocol.NFC;
    }

    @Override
    public int describeContents() {
        return 0;
    }

    @Override
    public void writeToParcel(Parcel parcel, int i) {
        parcel.writeParcelable(tag, i);
    }

    @Override
    public String toString() {
        return "NFC " + Helper.ByteArrayToHexString(tag.getId());
    }
}
