class ML::StreamsBlendingRecommender::AbstractSBR {

    has $!value;

    method setValue($arg) {
        $!value = $arg;
        self
    }

    method takeValue() {
        $!value
    }
}
