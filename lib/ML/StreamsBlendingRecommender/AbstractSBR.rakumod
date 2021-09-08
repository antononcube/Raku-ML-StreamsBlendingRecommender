class ML::StreamsBlendingRecommender::AbstractSBR {

    has $!value is rw;

    method setValue($arg) {
        $!value = $arg;
        self
    }

    method takeValue() {
        $!value
    }
}
